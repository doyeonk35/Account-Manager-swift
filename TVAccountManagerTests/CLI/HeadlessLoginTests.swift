import Testing
import Foundation
@testable import TVAccountManager

@Suite("CLI 인자 파싱")
struct CLIOptionsParseTests {

    private func run(_ argv: [String]) throws -> CLIOptions {
        guard case .run(let options) = try CLIOptions.parse(argv) else {
            Issue.record("run 명령이 아님: \(argv)")
            throw CLIUsageError(message: "not a run command")
        }
        return options
    }

    @Test("인자가 없으면 사용법")
    func noArguments() throws {
        #expect(try CLIOptions.parse([]) == .help)
    }

    @Test("도움말·버전 플래그")
    func helpAndVersion() throws {
        #expect(try CLIOptions.parse(["--help"]) == .help)
        #expect(try CLIOptions.parse(["-h"]) == .help)
        #expect(try CLIOptions.parse(["--version"]) == .version)
        #expect(try CLIOptions.parse(["-v"]) == .version)
    }

    @Test("env만 주면 목록 모드")
    func listMode() throws {
        let options = try run(["qa"])
        #expect(options.env == .qa)
        #expect(options.otp == nil)
    }

    @Test("env 대소문자를 가리지 않는다")
    func envIsCaseInsensitive() throws {
        #expect(try run(["QA"]).env == .qa)
        #expect(try run(["Prod"]).env == .prod)
    }

    @Test("env + otp 기본 조합")
    func envAndOTP() throws {
        let options = try run(["qa", "483920"])
        #expect(options.env == .qa)
        #expect(options.otp == "483920")
        #expect(options.profile == .auto)
        #expect(options.json == false)
        #expect(options.timeout == 120)
    }

    @Test("옵션 전체 조합")
    func allOptions() throws {
        let options = try run(["qc", "483920", "--account", "QA_BASIC", "--json", "--timeout", "60"])
        #expect(options.env == .qc)
        #expect(options.account == "QA_BASIC")
        #expect(options.json)
        #expect(options.timeout == 60)
    }

    @Test("옵션이 위치 인자보다 앞에 와도 된다")
    func optionsBeforePositional() throws {
        let options = try run(["--json", "qa", "483920"])
        #expect(options.env == .qa)
        #expect(options.otp == "483920")
        #expect(options.json)
    }

    @Test("프로필 지정과 생략")
    func profilePreference() throws {
        #expect(try run(["qa", "483920", "--profile", "키즈"]).profile == .named("키즈"))
        #expect(try run(["qa", "483920", "--no-profile"]).profile == .skip)
    }

    @Test("모르는 env는 거부한다")
    func unknownEnv() {
        #expect(throws: CLIUsageError.self) { try CLIOptions.parse(["stage", "483920"]) }
    }

    @Test("OTP는 숫자 6자리여야 한다", arguments: ["12345", "1234567", "48392a", "", "４８３９２０"])
    func invalidOTP(_ otp: String) {
        #expect(throws: CLIUsageError.self) { try CLIOptions.parse(["qa", otp]) }
    }

    @Test("프로필 지정과 생략은 동시에 못 쓴다")
    func profileFlagsAreExclusive() {
        #expect(throws: CLIUsageError.self) {
            try CLIOptions.parse(["qa", "483920", "--profile", "키즈", "--no-profile"])
        }
    }

    @Test("OTP 없이 계정·프로필 옵션만 주면 거부한다", arguments: [
        ["qa", "--account", "QA_BASIC"],
        ["qa", "--profile", "키즈"],
        ["qa", "--no-profile"],
    ])
    func optionsNeedOTP(_ argv: [String]) {
        #expect(throws: CLIUsageError.self) { try CLIOptions.parse(argv) }
    }

    @Test("모르는 옵션은 거부한다")
    func unknownOption() {
        #expect(throws: CLIUsageError.self) { try CLIOptions.parse(["qa", "483920", "--loud"]) }
    }

    @Test("값이 필요한 옵션에 값이 없으면 거부한다")
    func missingOptionValue() {
        #expect(throws: CLIUsageError.self) { try CLIOptions.parse(["qa", "483920", "--account"]) }
        #expect(throws: CLIUsageError.self) { try CLIOptions.parse(["qa", "483920", "--timeout"]) }
    }

    @Test("타임아웃은 양수여야 한다", arguments: ["0", "-5", "quick"])
    func invalidTimeout(_ raw: String) {
        #expect(throws: CLIUsageError.self) { try CLIOptions.parse(["qa", "483920", "--timeout", raw]) }
    }

    @Test("위치 인자가 셋이면 거부한다")
    func tooManyPositionals() {
        #expect(throws: CLIUsageError.self) { try CLIOptions.parse(["qa", "483920", "extra"]) }
    }
}

@Suite("CLI 환경 매핑")
struct CLIEnvTests {

    @Test("prod는 QC 계정 목록을 쓴다")
    func prodUsesQCAccounts() {
        #expect(CLIEnv.prod.accountType == .qc)
        #expect(CLIEnv.prod.filterTab == .qc)
        #expect(CLIEnv.qa.filterTab == .qa)
    }

    @Test("prod는 운영 URL로 간다")
    func prodUsesProductionURL() {
        #expect(CLIEnv.prod.loginURL.absoluteString == SettingsState.prodURL)
    }
}

@Suite("CLI 계정 매칭")
struct AccountMatchTests {

    private let accounts = [
        AccountInfo(title: "QA_BASIC", username: "webqa3"),
        AccountInfo(title: "QA_BASIC_2", username: "webqa4"),
        AccountInfo(title: "Premium", username: "webqa7"),
    ]

    @Test("완전 일치가 접두사보다 우선한다")
    func exactBeatsPrefix() {
        #expect(HeadlessLogin.match("QA_BASIC", in: accounts) == .one(accounts[0].id))
    }

    @Test("완전 일치는 대소문자를 가리지 않는다")
    func exactIsCaseInsensitive() {
        #expect(HeadlessLogin.match("qa_basic", in: accounts) == .one(accounts[0].id))
    }

    @Test("접두사가 하나면 그것을 고른다")
    func singlePrefix() {
        #expect(HeadlessLogin.match("Prem", in: accounts) == .one(accounts[2].id))
    }

    @Test("접두사가 여럿이면 후보를 돌려준다")
    func ambiguousPrefix() {
        #expect(HeadlessLogin.match("QA_", in: accounts) == .ambiguous(["QA_BASIC", "QA_BASIC_2"]))
    }

    @Test("username으로도 찾는다")
    func matchesUsername() {
        #expect(HeadlessLogin.match("webqa7", in: accounts) == .one(accounts[2].id))
    }

    @Test("없으면 none")
    func noMatch() {
        #expect(HeadlessLogin.match("없는계정", in: accounts) == .none)
        #expect(HeadlessLogin.match("   ", in: accounts) == .none)
    }
}

@Suite("LoginService 이름으로 프로필 찾기")
struct FindProfileTests {

    private func candidate(_ name: String, locked: Bool = false) -> ProfileCandidate {
        ProfileCandidate(name: name, locked: locked, restricted: false)
    }

    @Test("이름이 정확히 같은 프로필을 찾는다")
    func exactName() {
        let rows = [candidate("엄마"), candidate("키즈")]
        #expect(LoginService.findProfile(named: "키즈", in: rows) == .found(1))
    }

    @Test("대소문자를 가리지 않는다")
    func caseInsensitive() {
        let rows = [candidate("Kids"), candidate("Adult")]
        #expect(LoginService.findProfile(named: "kids", in: rows) == .found(0))
    }

    @Test("접두사로도 찾는다")
    func prefix() {
        let rows = [candidate("엄마"), candidate("키즈 프로필")]
        #expect(LoginService.findProfile(named: "키즈", in: rows) == .found(1))
    }

    @Test("잠긴 프로필은 locked로 알린다")
    func lockedTarget() {
        let rows = [candidate("엄마"), candidate("키즈", locked: true)]
        #expect(LoginService.findProfile(named: "키즈", in: rows) == .locked(1))
    }

    @Test("없는 이름은 notFound")
    func notFound() {
        let rows = [candidate("엄마"), candidate("키즈")]
        #expect(LoginService.findProfile(named: "아빠", in: rows) == .notFound)
    }

    @Test("빈 이름은 아무것도 고르지 않는다")
    func emptyName() {
        #expect(LoginService.findProfile(named: "  ", in: [candidate("엄마")]) == .notFound)
    }
}

@Suite("로그인 결과 판정")
struct LoginOutcomeTests {

    @Test("GUI는 프로필 대기도 성공으로 본다 — 사용자가 직접 고를 수 있다")
    func pendingIsSuccessForGUI() {
        #expect(LoginOutcome.submitted.isSuccess)
        #expect(LoginOutcome.profileSelected("엄마").isSuccess)
        #expect(LoginOutcome.profilePending.isSuccess)
        #expect(LoginOutcome.profileSkipped.isSuccess)
    }

    @Test("실패와 프로필 없음은 실패")
    func failuresAreNotSuccess() {
        #expect(!LoginOutcome.failed.isSuccess)
        #expect(!LoginOutcome.profileNotFound(["엄마"]).isSuccess)
    }
}
