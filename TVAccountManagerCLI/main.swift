import Foundation
import Noora

// tvlogin — 계정 선택 UI.
//
// 로그인 본체는 샌드박스된 앱 바이너리(이하 엔진)가 맡는다. 엔진은 컨테이너의 accounts.json과
// 키체인을 읽을 수 있지만, 샌드박스가 tty 제어 ioctl을 막아 터미널을 raw 모드로 바꾸지 못한다
// (`tcsetattr` → EPERM). 그래서 화살표 선택기는 샌드박스 밖인 이 바이너리가 띄우고,
// 고른 계정은 `--account`로 엔진에 넘긴다.
//
//   tvlogin qa 483920            →  엔진 `qa --json`으로 목록 → 선택기 → 엔진 `qa 483920 --account ...`
//   그 밖의 모든 호출            →  엔진에 그대로 전달 (목록·--json·--help·--account 지정 등)

private let valueFlags: Set<String> = ["--account", "--profile", "--timeout"]

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("tvlogin: \(message)\n".utf8))
    exit(2)
}

/// 같은 디렉터리(Contents/MacOS)에 있는 엔진 바이너리.
private func enginePath() -> String {
    let directory = URL(fileURLWithPath: CommandLine.arguments[0])
        .resolvingSymlinksInPath()
        .deletingLastPathComponent()
    for name in ["TVAccountManager", "TVAccountManager-Debug"] {
        let candidate = directory.appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate.path }
    }
    fail("앱 실행 파일을 \(directory.path) 에서 찾지 못했습니다")
}

/// 엔진을 그대로 실행하고 종료 코드를 물려받는다.
private func runEngine(_ arguments: [String]) -> Never {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: enginePath())
    process.arguments = arguments
    do {
        try process.run()
    } catch {
        fail("앱 실행에 실패했습니다: \(error.localizedDescription)")
    }
    process.waitUntilExit()
    exit(process.terminationStatus)
}

// MARK: - 엔진이 내려주는 계정 목록

private struct AccountRow: Decodable {
    let title: String
    let username: String
    let plan: String
    let pinned: Bool
    let hasPassword: Bool

    var label: String {
        "\(title)  ·  \(username)  ·  \(plan)\(pinned ? "  ★" : "")\(hasPassword ? "" : "  (비밀번호 없음)")"
    }
}

private struct AccountList: Decodable {
    let env: String
    let accounts: [AccountRow]
}

private func accounts(from engine: String, env: String) -> [AccountRow] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: engine)
    process.arguments = [env, "--json"]
    let pipe = Pipe()
    process.standardOutput = pipe
    do {
        try process.run()
    } catch {
        fail("계정 목록을 읽지 못했습니다: \(error.localizedDescription)")
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
    guard let list = try? JSONDecoder().decode(AccountList.self, from: data), !list.accounts.isEmpty
    else { fail("계정 목록을 해석하지 못했습니다") }
    return list.accounts
}

// MARK: - 선택기

private enum Choice: CustomStringConvertible, Equatable {
    case account(String)   // title
    case cancel

    var description: String {
        switch self {
        case .account(let label): label
        case .cancel: "취소"
        }
    }
}

/// Ctrl-C로 빠져나갈 때 되돌릴 터미널 상태.
///
/// Noora의 raw 모드는 `ECHO`·`ICANON`만 끄고 `ISIG`는 켜둔 채라 Ctrl-C가 바이트가 아니라
/// SIGINT로 도착한다. Noora의 `.restoreAndExit`는 그 시그널에서 **exit(0)** 을 부르고
/// (취소가 "로그인 완료"로 보인다), `.restoreOnly`는 종료를 안 해서 프롬프트가 멈춘 채로 남는다.
/// 그래서 `.none`으로 Noora의 핸들러를 끄고 여기서 직접 처리한다.
private nonisolated(unsafe) var savedTermios = termios()

private func handleInterrupt() {
    tcgetattr(STDIN_FILENO, &savedTermios)
    signal(SIGINT) { _ in
        // 시그널 핸들러 — async-signal-safe한 것만 쓴다 (tcsetattr, write, _exit).
        tcsetattr(STDIN_FILENO, TCSANOW, &savedTermios)
        let restoreCursor = "\u{1b}[?25h\n"
        _ = restoreCursor.withCString { write(STDERR_FILENO, $0, strlen($0)) }
        _exit(130)
    }
}

private func pick(from rows: [AccountRow], env: String) -> String? {
    let options: [Choice] = rows.map { .account($0.label) } + [.cancel]
    handleInterrupt()

    // 목록은 stderr로 — stdout은 엔진의 --json 결과 전용이다.
    let picked = Noora(
        terminal: Terminal(signalBehavior: .none),
        standardPipelines: StandardPipelines(output: StandardErrorPipeline())
    ).singleChoicePrompt(
        title: TerminalText(stringLiteral: env.uppercased()),
        question: "로그인할 계정",
        options: options,
        filterMode: .toggleable
    )

    guard case .account(let label) = picked,
          let row = rows.first(where: { $0.label == label })
    else { return nil }
    return row.title
}

// MARK: - 진입점

let argv = Array(CommandLine.arguments.dropFirst())

var positionals: [String] = []
var hasAccount = false
var index = 0
while index < argv.count {
    let argument = argv[index]
    if argument == "--account" { hasAccount = true }
    if valueFlags.contains(argument) {
        index += 2
        continue
    }
    if !argument.hasPrefix("-") { positionals.append(argument) }
    index += 1
}

// env와 otp가 모두 있고, 계정 지정이 없고, 터미널이면 선택기를 띄운다.
guard positionals.count == 2, !hasAccount, isatty(STDIN_FILENO) == 1 else {
    runEngine(argv)
}

private let engine = enginePath()
private let rows = accounts(from: engine, env: positionals[0])
guard let title = pick(from: rows, env: positionals[0]) else {
    exit(130)   // 사용자 취소
}
runEngine(argv + ["--account", title])
