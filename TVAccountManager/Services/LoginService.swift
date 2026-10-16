import Foundation
import WebKit

enum LoginStep: String {
    case navigating = "Navigating..."
    case enteringOTP = "Entering OTP..."
    case clickingLogin = "Opening login page..."
    case enteringCredentials = "Entering credentials..."
    case submitting = "Submitting..."
    case selectingProfile = "Selecting profile..."
    case verifying = "Verifying..."
    case success = "Login successful!"
    case failed = "Login failed."
}

/// 로그인 시퀀스의 최종 결과. GUI는 창이 떠 있어 사용자가 직접 이어갈 수 있지만,
/// 헤드리스(CLI)는 클릭할 창이 없으므로 "프로필 대기"를 성공으로 뭉개면 거짓 보고가 된다.
enum LoginOutcome: Sendable, Equatable {
    case submitted                  // 프로필 선택 화면이 없음 (프로필 1개)
    case profileSelected(String)
    case profileSkipped             // 요청대로 프로필을 안 골랐음 (--no-profile)
    case profilePending             // 전부 잠김 / 클릭 실패 — 사람이 직접 골라야 함
    case profileNotFound([String])  // 지정한 이름이 없음 — 후보 목록
    case failed

    /// GUI 기준 성공 여부. 사람이 직접 프로필을 고를 수 있으면 성공으로 본다.
    var isSuccess: Bool {
        switch self {
        case .submitted, .profileSelected, .profileSkipped, .profilePending: true
        case .profileNotFound, .failed: false
        }
    }
}

/// 프로필 선택 방식. GUI는 항상 `.auto`.
enum ProfilePreference: Sendable, Equatable {
    case auto
    case named(String)
    case skip
}

@MainActor
final class LoginService: NSObject {
    private weak var webView: WKWebView?
    private var account: AccountInfo?
    private var otpCode: String = ""
    private var onStatusUpdate: ((LoginStep, String) -> Void)?
    private var onComplete: ((LoginOutcome, String) -> Void)?
    private var loginTask: Task<Void, Never>?
    private var profilePreference: ProfilePreference = .auto

    func configure(
        webView: WKWebView,
        account: AccountInfo,
        otpCode: String,
        profile: ProfilePreference = .auto,
        onStatusUpdate: @escaping (LoginStep, String) -> Void,
        onComplete: @escaping (LoginOutcome, String) -> Void
    ) {
        self.webView = webView
        self.account = account
        self.otpCode = otpCode
        self.profilePreference = profile
        self.onStatusUpdate = onStatusUpdate
        self.onComplete = onComplete
    }

    func cancel() {
        loginTask?.cancel()
        loginTask = nil
    }

    func startLoginSequence() {
        guard let account = account else { return }

        loginTask = Task { @MainActor in
            do {
                // OTP 처리
                if !otpCode.isEmpty {
                    try Task.checkCancellation()
                    onStatusUpdate?(.enteringOTP, LoginStep.enteringOTP.rawValue)
                    try await injectOTP(otpCode)
                    try await Task.sleep(for: .seconds(1))
                }

                // "티빙 아이디로 로그인" 버튼 자동 클릭 시도
                try Task.checkCancellation()
                onStatusUpdate?(.clickingLogin, String(localized: "[\(account.accountType.rawValue.uppercased())] Looking for TVING ID login button..."))
                try await autoClickLoginMethod()

                // ID 입력 필드가 나타날 때까지 대기
                try Task.checkCancellation()
                onStatusUpdate?(.clickingLogin, String(localized: "Waiting for login form..."))
                for _ in 0..<500 {
                    try Task.checkCancellation()
                    let found = (try? await executeJS("""
                        (function() {
                            var f = document.querySelector('input[name="id"]')
                                 || document.querySelector('input[placeholder="아이디"]');
                            return f ? 'found' : 'not_found';
                        })()
                    """)) ?? "not_found"
                    if found == "found" { break }
                    try await Task.sleep(for: .milliseconds(300))
                }

                // 로그인 폼 셀렉터 (아이디/비밀번호 — 입력·재확인 공용)
                let usernameSelectors = [
                    "input[name=\"id\"]",
                    "input[autocomplete=\"username\"]",
                    "input[placeholder=\"아이디\"]",
                ]
                let passwordSelectors = [
                    "input[name=\"password\"]",
                    "input[autocomplete=\"current-password\"]",
                    "input[placeholder=\"비밀번호\"]",
                ]

                // 아이디 입력
                try Task.checkCancellation()
                onStatusUpdate?(.enteringCredentials, String(localized: "Entering username..."))
                guard try await waitAndFill(selectors: usernameSelectors, value: account.username) else {
                    onComplete?(.failed, String(localized: "Could not find username field."))
                    return
                }
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(300))

                // 비밀번호 입력
                try Task.checkCancellation()
                onStatusUpdate?(.enteringCredentials, String(localized: "Entering password..."))
                guard try await waitAndFill(selectors: passwordSelectors, value: account.password) else {
                    onComplete?(.failed, String(localized: "Could not find password field."))
                    return
                }

                // "로그인" 버튼 클릭 전 최종 확인: 제출 직전 React가 필드를 비웠으면 한 번 더 채운다
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(300))
                if try await isFieldEmpty(usernameSelectors) {
                    _ = try await waitAndFill(selectors: usernameSelectors, value: account.username)
                }
                if try await isFieldEmpty(passwordSelectors) {
                    _ = try await waitAndFill(selectors: passwordSelectors, value: account.password)
                }
                let usernameFilled = !(try await isFieldEmpty(usernameSelectors))
                let passwordFilled = !(try await isFieldEmpty(passwordSelectors))
                guard usernameFilled, passwordFilled else {
                    onComplete?(.failed, String(localized: "Login form was cleared before submit. Please try again."))
                    return
                }

                // "로그인" 버튼 자동 클릭 시도
                onStatusUpdate?(.submitting, String(localized: "Clicking login button..."))
                let loginClicked = try await autoClickLoginSubmit()

                let env = account.accountType.rawValue.uppercased()
                if loginClicked {
                    // 프로필이 여러 개면 프로필 선택까지 끝내야 로그인이 완료된다
                    onStatusUpdate?(.selectingProfile, String(localized: "Checking for profile selection..."))
                    switch try await selectProfile(preference: profilePreference) {
                    case .notShown:
                        finish(.submitted, String(localized: "[\(env)] \(account.title) — Login submitted"))
                    case .selected(let name):
                        finish(.profileSelected(name), String(localized: "[\(env)] \(account.title) — Profile \(name) selected"))
                    case .allLocked:
                        finish(.profilePending, String(localized: "[\(env)] \(account.title) — All profiles locked, select one yourself"))
                    case .selectFailed:
                        finish(.profilePending, String(localized: "[\(env)] \(account.title) — Profile not selected, select one yourself"))
                    case .skipped:
                        finish(.profileSkipped, String(localized: "[\(env)] \(account.title) — Stopped at profile selection"))
                    case .lockedTarget(let name):
                        finish(.profilePending, String(localized: "[\(env)] \(account.title) — Profile \(name) is locked"))
                    case .notFound(let names):
                        finish(.profileNotFound(names), String(localized: "[\(env)] \(account.title) — Profile not found"))
                    }
                } else {
                    onStatusUpdate?(.enteringCredentials, String(localized: "[\(env)] \(account.title) — Credentials filled. Please click Login."))
                    onComplete?(.submitted, String(localized: "[\(env)] \(account.title) — Credentials filled"))
                }
            } catch is CancellationError {
                // Sheet dismissed — silently stop
            } catch {
                let env = account.accountType.rawValue.uppercased()
                onComplete?(.failed, String(localized: "[\(env)] \(account.title) — Login failed: \(error.localizedDescription)"))
            }
        }
    }

    /// 상태 표시와 최종 보고를 같은 문장으로 묶는다.
    private func finish(_ outcome: LoginOutcome, _ message: String) {
        onStatusUpdate?(outcome.isSuccess ? .success : .failed, message)
        onComplete?(outcome, message)
    }

    // MARK: - OTP

    private func injectOTP(_ code: String) async throws {
        // #code-num01 필드가 나타날 때까지 대기 (최대 10초)
        for _ in 0..<20 {
            try Task.checkCancellation()
            let found = (try? await executeJS("""
                (function() { return document.querySelector('#code-num01') ? 'found' : 'not_found'; })()
            """)) ?? "not_found"
            if found == "found" { break }
            try await Task.sleep(for: .milliseconds(500))
        }

        // OTP 6자리를 #code-num01 ~ #code-num06 각 필드에 한 자리씩 입력
        // 이 페이지는 바닐라 JS (oninput="add(this)") 사용
        let digits = Array(code.prefix(6))
        for (i, digit) in digits.enumerated() {
            try Task.checkCancellation()
            let fieldId = String(format: "#code-num%02d", i + 1)
            try await executeJS("""
                (function() {
                    var f = document.querySelector('\(fieldId)');
                    if (f) {
                        f.focus();
                        f.value = '\(String(digit).escapedForJS)';
                        // oninput="add(this)" 한 번만 트리거
                        f.dispatchEvent(new Event('input', {bubbles: true}));
                    }
                })()
            """)
            try await Task.sleep(for: .milliseconds(150))
        }

        // "계속" 버튼 자동 클릭
        try await Task.sleep(for: .milliseconds(500))
        onStatusUpdate?(.enteringOTP, String(localized: "Clicking confirm..."))
        try await clickElement("#confirmBtn")

        // 페이지 이동 대기 (최대 100초, 자동 실패 시 사용자가 직접 클릭 가능)
        onStatusUpdate?(.enteringOTP, String(localized: "OTP submitted. Waiting for next page..."))
        for _ in 0..<200 {
            try Task.checkCancellation()
            let stillOnOTP = (try? await executeJS("""
                (function() { return document.querySelector('#code-num01') ? 'yes' : 'no'; })()
            """)) ?? "no"
            if stillOnOTP == "no" { break }
            try await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - Auto-click login method ("티빙 아이디로 로그인")

    private func autoClickLoginMethod() async throws {
        for _ in 0..<75 {
            try Task.checkCancellation()
            let result = (try? await executeJS("""
                (function() {
                    var link = document.querySelector('a[data-sentry-component="TvingIdLoginButton"]');
                    if (link) { link.click(); return 'clicked'; }
                    var btn = document.querySelector('button[aria-label="티빙 아이디로 로그인"]');
                    if (btn) { btn.click(); return 'clicked'; }
                    var byHref = document.querySelector('a[href*="/account/login/tving"]');
                    if (byHref) { byHref.click(); return 'clicked'; }
                    var els = document.querySelectorAll('a, button');
                    for (var i = 0; i < els.length; i++) {
                        var t = (els[i].textContent || '').trim();
                        if (t.includes('티빙 아이디') && t.includes('로그인')) {
                            els[i].click();
                            return 'clicked';
                        }
                    }
                    return 'not_found';
                })()
            """)) ?? "not_found"
            if result == "clicked" { return }
            try await Task.sleep(for: .milliseconds(300))
        }
    }

    // MARK: - Auto-click login submit ("로그인")

    private func autoClickLoginSubmit() async throws -> Bool {
        for _ in 0..<25 {
            try Task.checkCancellation()
            let result = (try? await executeJS("""
                (function() {
                    var submit = document.querySelector('button[type="submit"][data-sentry-source-file="LoginLayer.tsx"]');
                    if (submit) { submit.click(); return 'clicked'; }
                    submit = document.querySelector('form button[type="submit"]');
                    if (submit) { submit.click(); return 'clicked'; }
                    submit = document.querySelector('button[type="submit"]');
                    if (submit) { submit.click(); return 'clicked'; }
                    var btns = document.querySelectorAll('button');
                    for (var i = 0; i < btns.length; i++) {
                        var t = (btns[i].textContent || '').trim();
                        if (t === '로그인' || t === 'Login') {
                            btns[i].click();
                            return 'clicked';
                        }
                    }
                    return 'not_found';
                })()
            """)) ?? "not_found"
            if result == "clicked" { return true }
            try await Task.sleep(for: .milliseconds(300))
        }
        return false
    }

    // MARK: - Wait + Fill (React 호환)

    /// 셀렉터 중 첫 매칭 필드의 값이 비어 있으면 true. 필드를 못 찾아도 비었다고 간주한다.
    private func isFieldEmpty(_ selectors: [String]) async throws -> Bool {
        let selectorJS = selectors.map { "document.querySelector('\($0)')" }.joined(separator: " || ")
        let value = (try? await executeJS("""
            (function() {
                var f = \(selectorJS);
                return (f && f.value) ? f.value : '';
            })()
        """)) ?? ""
        return value.isEmpty
    }

    /// 셀렉터에 해당하는 엘리먼트가 나타나고, 입력값이 실제로 유지될 때까지 재시도하며 값 입력.
    /// React 컨트롤드 인풋은 필드가 DOM에 나타난 직후 마운트/재렌더되며 값을 되돌리므로,
    /// "값을 넣었다"만으로는 부족하다. 넣은 뒤 재렌더 여유를 두고 값이 남아 있는지 확인하고,
    /// 되돌아갔으면 재시도한다. (아이디·비밀번호 공용)
    private func waitAndFill(selectors: [String], value: String) async throws -> Bool {
        let selectorJS = selectors.map { "document.querySelector('\($0)')" }.joined(separator: " || ")
        let escaped = value.escapedForJS

        let fillJS = """
            (function() {
                var f = \(selectorJS);
                if (!f) return 'not_found';
                if (f.disabled || f.readOnly) return 'not_ready';

                f.focus();

                // React 호환: nativeInputValueSetter로 값 설정
                var nativeSetter = Object.getOwnPropertyDescriptor(
                    window.HTMLInputElement.prototype, 'value'
                ).set;
                nativeSetter.call(f, '\(escaped)');

                // 이벤트 디스패치 — React, Vue, Angular 모두 대응
                f.dispatchEvent(new Event('input', {bubbles: true}));
                f.dispatchEvent(new Event('change', {bubbles: true}));
                f.dispatchEvent(new KeyboardEvent('keydown', {bubbles: true}));
                f.dispatchEvent(new KeyboardEvent('keyup', {bubbles: true}));

                return 'filled';
            })()
        """
        // 재렌더 후 값이 남아 있는지 확인
        let verifyJS = """
            (function() {
                var f = \(selectorJS);
                if (!f) return 'gone';
                return f.value === '\(escaped)' ? 'ok' : 'reset';
            })()
        """

        // 필드가 나타나고 값이 유지될 때까지 재시도 (~16초: 30회 × (fill + 250ms + 300ms))
        for _ in 0..<30 {
            try Task.checkCancellation()
            let filled = (try? await executeJS(fillJS)) ?? "not_found"
            if filled == "filled" {
                // React 재렌더가 값을 되돌리는지 확인할 여유
                try await Task.sleep(for: .milliseconds(250))
                let verified = (try? await executeJS(verifyJS)) ?? "gone"
                if verified == "ok" { return true }
            }
            try await Task.sleep(for: .milliseconds(300))
        }
        return false
    }

    // MARK: - Click

    private func clickElement(_ selector: String, fallback: String? = nil) async throws {
        var js = "document.querySelector('\(selector)')"
        if let fb = fallback {
            js = "(\(js) || document.querySelector('\(fb)'))"
        }
        _ = try? await executeJS("(function() { var e = \(js); if (e) e.click(); })()")
    }

    // MARK: - JS Execution

    @discardableResult
    private func executeJS(_ js: String) async throws -> String {
        guard let webView = webView else { throw LoginError.webViewDeallocated }
        let result = try await webView.evaluateJavaScript(js)
        return (result as? String) ?? ""
    }

    // MARK: - Profile selection

    private enum ProfileSelection {
        case notShown              // 프로필이 1개거나 선택 화면이 안 뜬 경우
        case selected(String)
        case allLocked             // 잠긴 프로필만 있음 — 자동 선택 포기
        case selectFailed          // 클릭이 화면을 넘기지 못함
        case skipped               // .skip — 화면까지만 가고 선택 안 함
        case lockedTarget(String)  // .named 대상이 잠김
        case notFound([String])    // .named 이름 없음 — 후보 목록
    }

    /// 이름으로 프로필 찾기. 완전 일치(대소문자 무시) → 접두사 순.
    nonisolated static func findProfile(named name: String, in candidates: [ProfileCandidate]) -> ProfileLookup {
        let target = name.trimmingCharacters(in: .whitespaces)
        let hit = candidates.firstIndex { $0.name.caseInsensitiveCompare(target) == .orderedSame }
            ?? candidates.firstIndex { $0.name.lowercased().hasPrefix(target.lowercased()) && !target.isEmpty }
        guard let index = hit else { return .notFound }
        return candidates[index].locked ? .locked(index) : .found(index)
    }

    /// 잠금 없는 프로필 중 연령 제한 없는 쪽을 우선해 고른다. 전부 잠겼으면 nil.
    nonisolated static func pickProfile(from candidates: [ProfileCandidate]) -> Int? {
        let unlocked = candidates.enumerated().filter { !$0.element.locked }
        guard !unlocked.isEmpty else { return nil }
        return (unlocked.first { !$0.element.restricted } ?? unlocked[0]).offset
    }

    /// 프로필을 골라 클릭한다. `.auto`면 잠금 없는 것 중 연령 제한 없는 쪽 우선.
    ///
    /// 잠금은 DOM에도 자물쇠 오버레이로 드러나지만 **연령 제한은 DOM에 전혀 나타나지 않아**
    /// 서버가 내려준 profileList(`profilePwd`, `gradeCode`)를 읽는다. 파싱이 실패하거나
    /// 개수가 DOM과 어긋나면 DOM 자물쇠 판정으로만 폴백한다.
    private func selectProfile(preference: ProfilePreference) async throws -> ProfileSelection {
        // 로그인 제출 후 프로필 화면으로 넘어올 때까지 대기 (~15초)
        var table: [ProfileCandidate]?
        for _ in 0..<50 {
            try Task.checkCancellation()
            table = await readProfileTable()
            if table != nil { break }
            try await Task.sleep(for: .milliseconds(300))
        }
        guard let candidates = table else { return .notShown }

        let index: Int
        switch preference {
        case .skip:
            return .skipped
        case .named(let wanted):
            switch Self.findProfile(named: wanted, in: candidates) {
            case .found(let i): index = i
            case .locked(let i): return .lockedTarget(candidates[i].name)
            case .notFound: return .notFound(candidates.map(\.name))
            }
        case .auto:
            guard let auto = Self.pickProfile(from: candidates) else { return .allLocked }
            index = auto
        }
        let name = candidates[index].name

        // 클릭이 실제로 화면을 넘겼는지 확인하고 아니면 재시도.
        // ("클릭했다"만으로는 부족한 이유는 waitAndFill과 같다 — React가 되돌릴 수 있다)
        for _ in 0..<10 {
            try Task.checkCancellation()
            _ = try? await executeJS(Self.profileClickJS(index: index))
            try await Task.sleep(for: .milliseconds(600))
            if await readProfileTable() == nil { return .selected(name) }
        }
        return .selectFailed
    }

    /// 프로필 선택 화면이 아니거나 읽지 못하면 nil.
    private func readProfileTable() async -> [ProfileCandidate]? {
        guard let json = try? await executeJS(Self.profileTableJS),
              json != "none",
              let rows = try? JSONDecoder().decode([ProfileCandidate].self, from: Data(json.utf8)),
              !rows.isEmpty
        else { return nil }
        return rows
    }

    /// 연령 제한 없는 프로필의 등급 코드. 그 밖의 값(CPTG0007 등)은 연령 제한 프로필이다.
    private static let unrestrictedGradeCode = "CPTG0019"

    /// 프로필 버튼만 고른다 — 아바타 img를 가진 버튼. "프로필 편집"은 여기서 걸러진다.
    private static let profileButtonsJS = """
        var btns = Array.prototype.filter.call(
            document.querySelectorAll('button'),
            function(b) { return b.querySelector('img[alt]'); }
        );
        """

    private static let profileTableJS = """
        (function() {
            if (location.pathname.indexOf('/account/profiles') < 0) return 'none';
            \(profileButtonsJS)
            if (!btns.length) return 'none';

            // 서버가 내려준 프로필 원본 읽기. RSC 페이로드는 따옴표가 이스케이프돼 있어 먼저 되돌린다.
            // (백슬래시를 fromCharCode로 만들어 Swift 문자열 이스케이프를 피한다)
            var meta = null;
            try {
                var blob = '';
                var scripts = document.querySelectorAll('script');
                for (var i = 0; i < scripts.length; i++) blob += scripts[i].textContent || '';
                blob = blob.split(String.fromCharCode(92) + '"').join('"');

                var pwd = [], grade = [], m;
                var pwdRe = /"profilePwd"\\s*:\\s*(true|false)/g;
                while ((m = pwdRe.exec(blob)) !== null) pwd.push(m[1] === 'true');
                var gradeRe = /"gradeCode"\\s*:\\s*"([^"]*)"/g;
                while ((m = gradeRe.exec(blob)) !== null) grade.push(m[1]);

                if (pwd.length === btns.length && grade.length === btns.length) {
                    meta = { pwd: pwd, grade: grade };
                }
            } catch (e) {
                meta = null;
            }

            var rows = [];
            for (var j = 0; j < btns.length; j++) {
                // 페이로드가 없으면 자물쇠 오버레이(svg)로 판정. 편집 모드는 연필 svg가 붙어
                // 전부 잠김으로 보이므로 자동 선택이 일어나지 않는다.
                rows.push({
                    name: (btns[j].querySelector('img[alt]').getAttribute('alt') || '').trim(),
                    locked: meta ? meta.pwd[j] : !!btns[j].querySelector('svg'),
                    restricted: meta ? (meta.grade[j] !== '\(unrestrictedGradeCode)') : false
                });
            }
            return JSON.stringify(rows);
        })()
        """

    private static func profileClickJS(index: Int) -> String {
        """
        (function() {
            if (location.pathname.indexOf('/account/profiles') < 0) return 'gone';
            \(profileButtonsJS)
            if (!btns[\(index)]) return 'gone';
            btns[\(index)].click();
            return 'clicked';
        })()
        """
    }
}

/// 이름으로 프로필을 찾은 결과.
enum ProfileLookup: Equatable {
    case found(Int)
    case locked(Int)
    case notFound
}

/// 프로필 선택 화면에서 읽어온 프로필 하나.
struct ProfileCandidate: Decodable {
    let name: String
    let locked: Bool
    /// 연령 제한 프로필(7+/12+ 등). 선택 후순위로 밀린다.
    let restricted: Bool
}

enum LoginError: LocalizedError {
    case webViewDeallocated
    var errorDescription: String? { "WebView is no longer available" }
}

extension String {
    var escapedForJS: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            .replacingOccurrences(of: "<", with: "\\x3c")
            .replacingOccurrences(of: ">", with: "\\x3e")
    }
}
