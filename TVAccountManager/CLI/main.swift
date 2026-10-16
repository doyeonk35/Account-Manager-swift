import Foundation

// 알려진 CLI 플래그이거나, "-"로 시작하지 않는 위치 인자일 때만 CLI 모드.
// "-"로 시작하는 모르는 인자는 전부 GUI로 흘려보낸다 — XCTest(`-XCTest ...`)와
// LaunchServices(`-psn_0_...`, `-NSDocumentRevisionsDebugMode`)가 그 경로로 들어온다.
private let cliFlags: Set<String> = ["--help", "-h", "--version", "-v"]
private let firstArgument = CommandLine.arguments.dropFirst().first
// 테스트 호스트로 실행될 때는 어떤 인자가 오든 GUI 경로로 간다.
private let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
private let isCLI = !isTestHost
    && (firstArgument.map { cliFlags.contains($0) || !$0.hasPrefix("-") } ?? false)

if isCLI {
    HeadlessLogin.run()
} else {
    TVAccountManagerApp.main()
}
