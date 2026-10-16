import AppKit
import Foundation
import WebKit

// MARK: - 환경

/// CLI가 받는 환경 인자. `prod`는 QC 계정 목록에 운영 URL을 쓴다 (설정은 안 건드림).
enum CLIEnv: String, CaseIterable {
    case qc, qa, prod

    var accountType: AccountType { self == .qa ? .qa : .qc }
    var filterTab: AccountFilterTab { self == .qa ? .qa : .qc }

    var loginURL: URL {
        self == .prod
            ? URL(string: SettingsState.prodURL)!
            : SettingsState.loginURL(for: accountType)
    }
}

// MARK: - 인자

struct CLIOptions: Equatable {
    var env: CLIEnv
    var otp: String?
    var account: String?
    var profile: ProfilePreference = .auto
    var json = false
    var timeout: Double = 120
}

enum CLICommand: Equatable {
    case help
    case version
    case run(CLIOptions)
}

struct CLIUsageError: Error, Equatable {
    let message: String
}

extension CLIOptions {
    /// 실행 파일 이름을 제외한 인자만 받는다.
    static func parse(_ argv: [String]) throws -> CLICommand {
        guard let first = argv.first else { return .help }
        if first == "--help" || first == "-h" { return .help }
        if first == "--version" || first == "-v" { return .version }

        var positional: [String] = []
        var account: String?
        var profileName: String?
        var noProfile = false
        var json = false
        var timeout: Double = 120

        var index = 0
        func value(for flag: String) throws -> String {
            guard index + 1 < argv.count else {
                throw CLIUsageError(message: "\(flag) needs a value")
            }
            index += 1
            return argv[index]
        }

        while index < argv.count {
            let argument = argv[index]
            switch argument {
            case "--account": account = try value(for: argument)
            case "--profile": profileName = try value(for: argument)
            case "--no-profile": noProfile = true
            case "--json": json = true
            case "--timeout":
                let raw = try value(for: argument)
                guard let seconds = Double(raw), seconds > 0 else {
                    throw CLIUsageError(message: "--timeout needs a positive number, got '\(raw)'")
                }
                timeout = seconds
            default:
                guard !argument.hasPrefix("-") else {
                    throw CLIUsageError(message: "unknown option '\(argument)'")
                }
                positional.append(argument)
            }
            index += 1
        }

        guard let envArgument = positional.first else {
            throw CLIUsageError(message: "missing <env>")
        }
        guard positional.count <= 2 else {
            throw CLIUsageError(message: "too many arguments: \(positional.dropFirst(2).joined(separator: " "))")
        }
        guard let env = CLIEnv(rawValue: envArgument.lowercased()) else {
            throw CLIUsageError(message: "unknown env '\(envArgument)' — use qc, qa, or prod")
        }

        let otp = positional.count == 2 ? positional[1] : nil
        if let otp {
            guard otp.count == 6, otp.allSatisfy({ $0.isASCII && $0.isNumber }) else {
                throw CLIUsageError(message: "<otp> must be 6 digits, got '\(otp)'")
            }
        } else if account != nil || profileName != nil || noProfile {
            throw CLIUsageError(message: "--account/--profile/--no-profile need <otp>")
        }

        guard !(noProfile && profileName != nil) else {
            throw CLIUsageError(message: "--profile and --no-profile are mutually exclusive")
        }

        let profile: ProfilePreference = noProfile ? .skip : profileName.map { .named($0) } ?? .auto
        return .run(CLIOptions(
            env: env, otp: otp, account: account, profile: profile, json: json, timeout: timeout
        ))
    }
}

// MARK: - 계정 매칭

/// `--account` 질의 결과. 에이전트가 정정할 수 있도록 후보를 돌려준다.
enum AccountMatch: Equatable {
    case one(UUID)
    case none
    case ambiguous([String])
}

// MARK: - 종료 코드

enum ExitCode: Int32 {
    case ok = 0
    case loginFailed = 1
    case usage = 2
    case timeout = 3
    case needsHuman = 4   // 프로필 전부 잠김 등 사람이 직접 해야 하는 상태
    case cancelled = 130
}

// MARK: - 실행

enum HeadlessLogin {

    // MARK: 진입점

    @MainActor
    static func run() -> Never {
        let argv = Array(CommandLine.arguments.dropFirst())
        let command: CLICommand
        do {
            command = try CLIOptions.parse(argv)
        } catch let error as CLIUsageError {
            printErr("tvlogin: \(error.message)")
            printErr("")
            printErr(usageText)
            exit(ExitCode.usage.rawValue)
        } catch {
            printErr("tvlogin: \(error.localizedDescription)")
            exit(ExitCode.usage.rawValue)
        }

        switch command {
        case .help:
            print(usageText)
            exit(ExitCode.ok.rawValue)
        case .version:
            print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
            exit(ExitCode.ok.rawValue)
        case .run(let options):
            start(options)
        }
    }

    // MARK: 계정 선택 → 로그인

    @MainActor
    private static func start(_ options: CLIOptions) -> Never {
        let accounts = loadAccounts(for: options.env)
        guard !accounts.isEmpty else {
            printErr(String(localized: "No accounts for this environment."))
            exit(ExitCode.usage.rawValue)
        }

        // OTP 없이 호출하면 목록만 출력한다.
        guard let otp = options.otp else {
            printList(accounts, env: options.env, json: options.json)
            exit(ExitCode.ok.rawValue)
        }

        let account: AccountInfo
        if let query = options.account {
            switch match(query, in: accounts) {
            case .one(let id):
                account = accounts.first { $0.id == id }!
            case .none:
                printErr(String(localized: "No account matches '\(query)'."))
                printList(accounts, env: options.env, json: false)
                exit(ExitCode.usage.rawValue)
            case .ambiguous(let titles):
                printErr(String(localized: "'\(query)' matches several accounts: \(titles.joined(separator: ", "))"))
                exit(ExitCode.usage.rawValue)
            }
        } else {
            // 계정 선택 UI는 샌드박스 밖의 tvlogin 헬퍼가 맡는다.
            // (샌드박스 안에서는 tcsetattr가 EPERM이라 터미널을 raw 모드로 바꿀 수 없다)
            printErr(String(localized: "Pass --account <title> to choose an account."))
            printList(accounts, env: options.env, json: false)
            exit(ExitCode.usage.rawValue)
        }

        guard !account.password.isEmpty else {
            printErr(String(localized: "No password in Keychain for \(account.title)."))
            exit(ExitCode.usage.rawValue)
        }

        let driver = Driver(account: account, otp: otp, options: options)
        NSApplication.shared.setActivationPolicy(.prohibited)   // Dock 아이콘·창 없음
        Task { @MainActor in driver.start() }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(options.timeout))
            driver.complete(.failed, String(localized: "Login timed out."), overriding: .timeout)
        }
        NSApplication.shared.run()
        exit(ExitCode.loginFailed.rawValue)   // run()은 complete()의 exit로만 빠져나온다
    }

    // MARK: 계정 로드

    @MainActor
    private static func loadAccounts(for env: CLIEnv) -> [AccountInfo] {
        // 필터·정렬은 GUI 목록과 같은 경로를 쓴다 (고정 ★ 먼저, 그다음 이름순).
        var state = AccountState()
        state.accounts = AccountUseCase(repository: AccountRepositoryImpl()).loadAccounts()
        state.filterTab = env.filterTab
        return state.sortedAccounts
    }

    /// title 완전 일치 → title 접두사 → username 완전 일치. 전부 대소문자 무시.
    static func match(_ query: String, in accounts: [AccountInfo]) -> AccountMatch {
        let target = query.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return .none }

        if let exact = accounts.first(where: { $0.title.caseInsensitiveCompare(target) == .orderedSame }) {
            return .one(exact.id)
        }
        let prefixed = accounts.filter { $0.title.lowercased().hasPrefix(target.lowercased()) }
        if prefixed.count == 1 { return .one(prefixed[0].id) }
        if prefixed.count > 1 { return .ambiguous(prefixed.map(\.title)) }

        if let byUsername = accounts.first(where: { $0.username.caseInsensitiveCompare(target) == .orderedSame }) {
            return .one(byUsername.id)
        }
        return .none
    }

    // MARK: 목록 출력

    private struct AccountRow: Encodable {
        let title: String
        let username: String
        let plan: String
        let pinned: Bool
        let hasPassword: Bool
    }

    private struct ListPayload: Encodable {
        let env: String
        let accounts: [AccountRow]
    }

    @MainActor
    private static func printList(_ accounts: [AccountInfo], env: CLIEnv, json: Bool) {
        if json {
            let payload = ListPayload(env: env.rawValue, accounts: accounts.map {
                AccountRow(
                    title: $0.title, username: $0.username, plan: $0.planType.rawValue,
                    pinned: $0.isPinned, hasPassword: !$0.password.isEmpty
                )
            })
            print(encode(payload))
            return
        }

        printErr("")
        printErr(header(for: env, count: accounts.count))
        for row in rowStrings(accounts) {
            printErr("    " + row)
        }
    }

    private static func header(for env: CLIEnv, count: Int) -> String {
        "  " + String(localized: "\(env.rawValue.uppercased()) accounts (\(count))")
    }

    /// 번호 · 타이틀 · username · 요금제 · 고정 표시. 선택기와 목록 출력이 같은 문자열을 쓴다.
    private static func rowStrings(_ accounts: [AccountInfo]) -> [String] {
        let titleWidth = accounts.map(\.title.displayWidth).max() ?? 0
        let usernameWidth = accounts.map(\.username.displayWidth).max() ?? 0
        return accounts.enumerated().map { offset, account in
            let number = String(format: "%2d", offset + 1)
            let title = account.title.padded(to: titleWidth)
            let username = account.username.padded(to: usernameWidth)
            let pin = account.isPinned ? " ★" : ""
            return "\(number)  \(title)  \(username)  \(account.planType.rawValue)\(pin)"
        }
    }

    // MARK: 선택 프롬프트

    // MARK: 출력 헬퍼

    private struct ResultPayload: Encodable {
        let ok: Bool
        let env: String
        let account: String
        let profile: String?
        let profiles: [String]?
        let exit: Int32
        let message: String
    }

    fileprivate static func encode(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    fileprivate static func printErr(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    // MARK: 로그인 구동

    /// 오프스크린 WebView로 기존 로그인 시퀀스를 그대로 돌린다.
    @MainActor
    private final class Driver: NSObject, WKNavigationDelegate {
        private let service = LoginService()
        private let account: AccountInfo
        private let otp: String
        private let options: CLIOptions
        private var window: NSWindow?
        private var hasStarted = false
        private var hasFinished = false

        init(account: AccountInfo, otp: String, options: CLIOptions) {
            self.account = account
            self.otp = otp
            self.options = options
            super.init()
        }

        func start() {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            let webView = WKWebView(
                frame: CGRect(x: 0, y: 0, width: 1280, height: 800), configuration: configuration
            )
            webView.navigationDelegate = self

            // 오프스크린 윈도우에 담아 타이머/렌더링 스로틀링을 피한다. 화면에는 안 뜬다.
            let window = NSWindow(
                contentRect: webView.frame, styleMask: [.borderless], backing: .buffered, defer: false
            )
            window.contentView = webView
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.orderBack(nil)
            self.window = window

            service.configure(
                webView: webView,
                account: account,
                otpCode: otp,
                profile: options.profile,
                onStatusUpdate: { _, message in printErr("    \(message)") },
                onComplete: { [weak self] outcome, message in self?.complete(outcome, message) }
            )

            printErr("  → \(account.title)")
            webView.load(URLRequest(url: options.env.loginURL))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasStarted else { return }
            hasStarted = true
            // GUI와 동일하게 첫 로드 후 2초 여유를 두고 시작한다.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                service.startLoginSequence()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            complete(.failed, String(localized: "Navigation failed: \(error.localizedDescription)"))
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            complete(.failed, String(localized: "Navigation failed: \(error.localizedDescription)"))
        }

        func complete(_ outcome: LoginOutcome, _ message: String, overriding code: ExitCode? = nil) {
            guard !hasFinished else { return }
            hasFinished = true
            service.cancel()

            var profile: String?
            var candidates: [String]?
            let exitCode: ExitCode
            switch outcome {
            case .submitted:
                exitCode = .ok
            case .profileSelected(let name):
                exitCode = .ok
                profile = name
            case .profileSkipped:
                // 사용자가 --no-profile로 요청한 중단이므로 이상 상태가 아니다.
                exitCode = .ok
            case .profilePending:
                exitCode = .needsHuman
            case .profileNotFound(let names):
                exitCode = .usage
                candidates = names
            case .failed:
                exitCode = .loginFailed
            }
            let finalCode = code ?? exitCode

            if options.json {
                print(encode(ResultPayload(
                    ok: finalCode == .ok, env: options.env.rawValue, account: account.title,
                    profile: profile, profiles: candidates, exit: finalCode.rawValue, message: message
                )))
            } else {
                print(message)
                if let candidates {
                    printErr("  " + String(localized: "Profiles: \(candidates.joined(separator: ", "))"))
                }
            }
            exit(finalCode.rawValue)
        }
    }

    // MARK: 사용법

    private static let usageText = """
    tvlogin — TV 페어링 코드로 TVING 계정에 로그인한다. 창은 뜨지 않는다.

    USAGE
        tvlogin <env> <otp> [options]
        tvlogin <env>
        tvlogin --help | --version

    ARGUMENTS
        <env>
            qc | qa | prod. prod는 QC 계정 목록에 운영 URL을 쓴다 (앱 설정은 바뀌지 않는다).

        <otp>
            TV 화면에 뜬 6자리 숫자. 생략하면 계정 목록만 출력하고 끝난다.

    OPTIONS
        --account <title>
            계정을 지정한다. title 완전일치 → title 접두사 → username 순으로 찾고,
            후보가 여럿이면 목록을 보여준 뒤 멈춘다.
            tvlogin으로 실행하면 생략 시 화살표 선택기가 뜬다. 앱 바이너리를 직접 호출할
            때는 필수다 — 샌드박스 안에서는 터미널을 raw 모드로 바꿀 수 없다.

        --profile <name>
            프로필을 이름으로 고른다. 기본은 잠기지 않은 프로필을 자동 선택한다.

        --no-profile
            프로필 선택 화면까지만 가고 멈춘다. 확인용이며 정상 로그인 경로가 아니다 —
            TV 로그인은 프로필을 골라야 완료된다.

        --json
            계정 목록과 최종 결과를 JSON으로 출력한다. 진행 상황은 그대로 stderr로 간다.

        --timeout <sec>
            로그인 시퀀스 상한(초). 기본 120.

    EXIT CODES
        0    로그인 완료
        1    로그인 실패 (폼을 못 찾거나 자격증명 거부)
        2    인자 오류, 해당 env에 계정 없음, 키체인에 비밀번호 없음
        3    타임아웃
        4    사람이 직접 해야 함 (프로필이 전부 PIN 잠김)
        130  사용자 취소

    EXAMPLES
        계정 목록 보기:

            tvlogin qa

        목록에서 번호를 골라 로그인 (빈 입력은 1번, q는 취소):

            tvlogin qa 483920

        계정을 지정하고 결과를 JSON으로 — 스크립트·에이전트용:

            tvlogin qa 483920 --account "QA 베이직" --json

        운영 URL로, 프로필을 이름으로 지정:

            tvlogin prod 483920 --profile 키즈
    """
}

private extension String {
    /// 터미널에서 차지하는 칸 수. 한글·CJK는 2칸이라 `count`로는 열이 어긋난다.
    var displayWidth: Int {
        unicodeScalars.reduce(0) { width, scalar in
            switch scalar.value {
            case 0x1100...0x115F, 0x2E80...0xA4CF, 0xAC00...0xD7A3,
                 0xF900...0xFAFF, 0xFE30...0xFE6F, 0xFF00...0xFF60, 0xFFE0...0xFFE6:
                width + 2
            default:
                width + 1
            }
        }
    }

    /// 번호 목록 정렬용 오른쪽 패딩.
    func padded(to width: Int) -> String {
        let shortfall = width - displayWidth
        return shortfall > 0 ? self + String(repeating: " ", count: shortfall) : self
    }
}
