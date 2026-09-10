import Testing
import Foundation
@testable import TVAccountManager

@Suite("PresetAccount Export")
struct PresetAccountsTests {

    // MARK: - File name

    @Test("내보내기 파일명은 초 단위까지 포함해 1초 차이도 다른 파일이 된다")
    func exportFileNameIncludesSeconds() {
        let base = Date()

        let first = PresetAccount.exportFileName(date: base)
        let second = PresetAccount.exportFileName(date: base.addingTimeInterval(1))

        #expect(first != second)
    }

    @Test("내보내기 파일명 형식은 accounts-export-yyyy-MM-dd-HHmmss.json 이다")
    func exportFileNameFormat() throws {
        let name = PresetAccount.exportFileName(date: Date())

        let pattern = try Regex(#"^accounts-export-\d{4}-\d{2}-\d{2}-\d{6}\.json$"#)
        #expect(name.contains(pattern))
    }

    // MARK: - Conversion from AccountInfo

    @Test("계정을 프리셋으로 변환할 때 비밀번호를 포함한다")
    func presetFromAccountWithPassword() {
        let account = AccountInfo(
            title: "QC 베이직",
            username: "u1",
            password: "p1",
            accountType: .qc,
            planType: .basic,
            memo: "m1"
        )

        let preset = PresetAccount(from: account, includePassword: true)

        #expect(preset.title == "QC 베이직")
        #expect(preset.username == "u1")
        #expect(preset.password == "p1")
        #expect(preset.accountType == .qc)
        #expect(preset.planType == .basic)
        #expect(preset.memo == "m1")
    }

    @Test("계정을 프리셋으로 변환할 때 비밀번호를 제외하면 빈 문자열이다")
    func presetFromAccountWithoutPassword() {
        let account = AccountInfo(title: "QA 프리미엄", username: "u2", password: "p2", accountType: .qa)

        let preset = PresetAccount(from: account, includePassword: false)

        #expect(preset.username == "u2")
        #expect(preset.password.isEmpty)
    }
}
