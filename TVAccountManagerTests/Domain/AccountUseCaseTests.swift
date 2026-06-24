import Testing
import Foundation
@testable import TVAccountManager

@Suite("AccountUseCase")
@MainActor
struct AccountUseCaseTests {

    let repository: MockAccountRepository
    let useCase: AccountUseCase

    init() {
        repository = MockAccountRepository()
        useCase = AccountUseCase(repository: repository)
    }

    // MARK: - loadAccounts

    @Test("계정 목록을 로드하고 키체인에서 비밀번호를 가져온다")
    func loadAccountsFromRepository() {
        repository.storedAccounts = [
            AccountInfo(title: "A1", username: "u1", accountType: .qc),
            AccountInfo(title: "A2", username: "u2", accountType: .qa),
        ]
        repository.storedPasswords = [
            repository.storedAccounts[0].id: "pw1",
            repository.storedAccounts[1].id: "pw2",
        ]

        let accounts = useCase.loadAccounts()

        #expect(accounts.count == 2)
        #expect(accounts[0].password == "pw1")
        #expect(accounts[1].password == "pw2")
        #expect(repository.loadAccountsCallCount == 1)
    }

    @Test("Rust JSON의 평문 비밀번호를 키체인으로 마이그레이션한다")
    func loadAccountsMigratesPlaintextPasswords() {
        let account = AccountInfo(title: "Rust", username: "u", password: "plaintext_pw")
        repository.storedAccounts = [account]

        let accounts = useCase.loadAccounts()

        #expect(accounts[0].password == "")
        #expect(repository.storedPasswords[account.id] == "plaintext_pw")
        #expect(repository.savePasswordCallCount == 1)
        #expect(repository.saveAccountsCallCount == 1)
    }

    @Test("마이그레이션이 불필요하면 재저장하지 않는다")
    func loadAccountsNoMigrationWhenClean() {
        let account = AccountInfo(title: "Clean", username: "u")
        repository.storedAccounts = [account]
        repository.storedPasswords = [account.id: "keychain_pw"]

        let accounts = useCase.loadAccounts()

        #expect(accounts[0].password == "keychain_pw")
        #expect(repository.savePasswordCallCount == 0)
        #expect(repository.saveAccountsCallCount == 0)
    }

    @Test("빈 저장소에서 빈 배열을 반환한다")
    func loadAccountsReturnsEmpty() {
        let accounts = useCase.loadAccounts()
        #expect(accounts.isEmpty)
    }

    @Test("키체인에 비밀번호가 없으면 빈 문자열을 반환한다")
    func loadAccountsHandlesMissingKeychainPassword() {
        repository.storedAccounts = [AccountInfo(title: "A", username: "u")]

        let accounts = useCase.loadAccounts()
        #expect(accounts[0].password == "")
    }

    // MARK: - addAccount

    @Test("새 계정을 추가한다")
    func addAccountAppendsToList() {
        var accounts: [AccountInfo] = []

        useCase.addAccount(to: &accounts, title: "New", username: "user1",
                          password: "pw", accountType: .qc, planType: .basic, memo: "test memo")

        #expect(accounts.count == 1)
        #expect(accounts[0].title == "New")
        #expect(accounts[0].username == "user1")
        #expect(accounts[0].accountType == .qc)
        #expect(accounts[0].planType == .basic)
        #expect(accounts[0].memo == "test memo")
    }

    @Test("추가 시 비밀번호를 리포지토리에 저장한다")
    func addAccountSavesPassword() {
        var accounts: [AccountInfo] = []

        useCase.addAccount(to: &accounts, title: "A", username: "u",
                          password: "secret", accountType: .qc, planType: .basic, memo: "")

        #expect(repository.storedPasswords[accounts[0].id] == "secret")
        #expect(repository.savePasswordCallCount == 1)
    }

    @Test("추가 시 계정 목록을 영속화한다")
    func addAccountPersists() {
        var accounts: [AccountInfo] = []

        useCase.addAccount(to: &accounts, title: "A", username: "u",
                          password: "p", accountType: .qc, planType: .basic, memo: "")

        #expect(repository.saveAccountsCallCount == 1)
        #expect(repository.storedAccounts.count == 1)
    }

    @Test("빈 제목이면 랜덤 제목을 생성한다")
    func addAccountGeneratesRandomTitleForEmpty() {
        var accounts: [AccountInfo] = []

        useCase.addAccount(to: &accounts, title: "", username: "u",
                          password: "p", accountType: .qc, planType: .basic, memo: "")

        #expect(!accounts[0].title.isEmpty)
    }

    @Test("공백만 있는 제목이면 랜덤 제목을 생성한다")
    func addAccountGeneratesRandomTitleForWhitespace() {
        var accounts: [AccountInfo] = []

        useCase.addAccount(to: &accounts, title: "   ", username: "u",
                          password: "p", accountType: .qc, planType: .basic, memo: "")

        #expect(!accounts[0].title.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test("기존 계정을 보존하며 추가한다")
    func addAccountPreservesExisting() {
        var accounts = [AccountInfo(title: "Existing", username: "u1")]

        useCase.addAccount(to: &accounts, title: "New", username: "u2",
                          password: "p", accountType: .qc, planType: .basic, memo: "")

        #expect(accounts.count == 2)
        #expect(accounts[0].title == "Existing")
        #expect(accounts[1].title == "New")
    }

    // MARK: - updateAccount

    @Test("계정 필드를 수정한다")
    func updateAccountModifiesFields() {
        var accounts = [AccountInfo(title: "Old", username: "old_user", accountType: .qc, planType: .basic)]
        let id = accounts[0].id

        useCase.updateAccount(in: &accounts, id: id, title: "New", username: "new_user",
                             password: "new_pw", accountType: .qa, planType: .premium, memo: "updated")

        #expect(accounts[0].title == "New")
        #expect(accounts[0].username == "new_user")
        #expect(accounts[0].accountType == .qa)
        #expect(accounts[0].planType == .premium)
        #expect(accounts[0].memo == "updated")
    }

    @Test("수정 시 새 비밀번호를 저장한다")
    func updateAccountSavesNewPassword() {
        var accounts = [AccountInfo(title: "A", username: "u")]
        let id = accounts[0].id

        useCase.updateAccount(in: &accounts, id: id, title: "A", username: "u",
                             password: "new_pw", accountType: .qc, planType: .basic, memo: "")

        #expect(repository.storedPasswords[id] == "new_pw")
    }

    @Test("수정 시 빈 제목이면 랜덤 제목을 생성한다")
    func updateAccountGeneratesRandomTitleForEmpty() {
        var accounts = [AccountInfo(title: "Old", username: "u")]
        let id = accounts[0].id

        useCase.updateAccount(in: &accounts, id: id, title: "", username: "u",
                             password: "p", accountType: .qc, planType: .basic, memo: "")

        #expect(!accounts[0].title.isEmpty)
        #expect(accounts[0].title != "Old")
    }

    @Test("존재하지 않는 ID를 무시한다")
    func updateAccountIgnoresNonexistentId() {
        var accounts = [AccountInfo(title: "A", username: "u")]
        let originalTitle = accounts[0].title

        useCase.updateAccount(in: &accounts, id: UUID(), title: "Changed", username: "u2",
                             password: "p", accountType: .qa, planType: .premium, memo: "")

        #expect(accounts[0].title == originalTitle)
        #expect(repository.saveAccountsCallCount == 0)
    }

    // MARK: - deleteAccount

    @Test("계정을 삭제한다")
    func deleteAccountRemovesFromList() {
        var accounts = [
            AccountInfo(title: "A", username: "u1"),
            AccountInfo(title: "B", username: "u2"),
        ]
        let idToDelete = accounts[0].id

        useCase.deleteAccount(from: &accounts, id: idToDelete)

        #expect(accounts.count == 1)
        #expect(accounts[0].title == "B")
    }

    @Test("삭제 시 키체인 비밀번호도 제거한다")
    func deleteAccountRemovesPassword() {
        var accounts = [AccountInfo(title: "A", username: "u")]
        let id = accounts[0].id
        repository.storedPasswords[id] = "pw"

        useCase.deleteAccount(from: &accounts, id: id)

        #expect(repository.storedPasswords[id] == nil)
        #expect(repository.deletePasswordCallCount == 1)
    }

    @Test("삭제 결과를 영속화한다")
    func deleteAccountPersists() {
        var accounts = [AccountInfo(title: "A", username: "u")]
        let id = accounts[0].id

        useCase.deleteAccount(from: &accounts, id: id)

        #expect(repository.saveAccountsCallCount == 1)
        #expect(repository.storedAccounts.isEmpty)
    }

    // MARK: - markUsed

    @Test("사용일시를 업데이트한다")
    func markUsedUpdatesLastUsedDate() {
        let oldDate = Date.distantPast
        var accounts = [AccountInfo(title: "A", username: "u", lastUsed: oldDate)]
        let id = accounts[0].id

        useCase.markUsed(in: &accounts, id: id)

        #expect(accounts[0].lastUsed > oldDate)
        #expect(repository.saveAccountsCallCount == 1)
    }

    @Test("존재하지 않는 ID의 markUsed를 무시한다")
    func markUsedIgnoresNonexistentId() {
        let oldDate = Date.distantPast
        var accounts = [AccountInfo(title: "A", username: "u", lastUsed: oldDate)]

        useCase.markUsed(in: &accounts, id: UUID())

        #expect(accounts[0].lastUsed == oldDate)
        #expect(repository.saveAccountsCallCount == 0)
    }

    // MARK: - loadPassword

    @Test("리포지토리에서 비밀번호를 로드한다")
    func loadPasswordReturnsFromRepository() {
        let id = UUID()
        repository.storedPasswords[id] = "secret"
        #expect(useCase.loadPassword(forAccountId: id) == "secret")
    }

    @Test("없는 비밀번호는 nil을 반환한다")
    func loadPasswordReturnsNilForMissing() {
        #expect(useCase.loadPassword(forAccountId: UUID()) == nil)
    }

    // MARK: - importPresetAccounts

    private func writePresetsFile(_ presets: [PresetAccount]) throws {
        let dir = PresetAccount.presetsDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(presets)
        try data.write(to: PresetAccount.presetsFileURL)
    }

    private func removePresetsFile() {
        try? FileManager.default.removeItem(at: PresetAccount.presetsFileURL)
    }

    @Test("프리셋 파일이 없으면 fileNotFound를 반환한다")
    func importPresetsFileNotFound() {
        removePresetsFile()
        var accounts: [AccountInfo] = []

        let result = useCase.importPresetAccounts(into: &accounts)

        guard case .fileNotFound = result else {
            Issue.record("Expected .fileNotFound, got \(result)")
            return
        }
        #expect(accounts.isEmpty)
    }

    @Test("프리셋 계정을 빈 목록에 모두 불러온다")
    func importPresetsIntoEmptyList() throws {
        let presets = [
            PresetAccount(title: "QC Basic", username: "qc@test.com", password: "pw1", accountType: .qc, planType: .basic),
            PresetAccount(title: "QA Basic", username: "qa@test.com", password: "pw2", accountType: .qa, planType: .basic),
        ]
        try writePresetsFile(presets)
        defer { removePresetsFile() }

        var accounts: [AccountInfo] = []
        let result = useCase.importPresetAccounts(into: &accounts)

        guard case .success(let imported, let skipped) = result else {
            Issue.record("Expected .success, got \(result)")
            return
        }
        #expect(imported == 2)
        #expect(skipped == 0)
        #expect(accounts.count == 2)
        #expect(repository.saveAccountsCallCount == 1)
        #expect(repository.savePasswordCallCount == 2)
    }

    @Test("중복 계정은 건너뛴다")
    func importPresetsSkipsDuplicates() throws {
        let presets = [
            PresetAccount(title: "QC Basic", username: "qc@test.com", password: "pw1", accountType: .qc),
            PresetAccount(title: "QA Basic", username: "qa@test.com", password: "pw2", accountType: .qa),
        ]
        try writePresetsFile(presets)
        defer { removePresetsFile() }

        var accounts = [
            AccountInfo(title: "Existing", username: "qc@test.com", accountType: .qc)
        ]

        let result = useCase.importPresetAccounts(into: &accounts)

        guard case .success(let imported, let skipped) = result else {
            Issue.record("Expected .success")
            return
        }
        #expect(imported == 1)
        #expect(skipped == 1)
        #expect(accounts.first?.title == "Existing")
    }

    @Test("모든 프리셋이 이미 존재하면 저장하지 않는다")
    func importPresetsAllDuplicatesNoSave() throws {
        let presets = [
            PresetAccount(title: "A", username: "u1@test.com", password: "pw", accountType: .qc),
        ]
        try writePresetsFile(presets)
        defer { removePresetsFile() }

        var accounts = [
            AccountInfo(title: "A", username: "u1@test.com", accountType: .qc)
        ]

        let result = useCase.importPresetAccounts(into: &accounts)

        guard case .success(let imported, let skipped) = result else {
            Issue.record("Expected .success")
            return
        }
        #expect(imported == 0)
        #expect(skipped == 1)
        #expect(repository.saveAccountsCallCount == 0)
    }

    @Test("같은 아이디라도 다른 환경(QC/QA)이면 별도로 등록한다")
    func importPresetsDistinguishesByAccountType() throws {
        let presets = [
            PresetAccount(title: "QC ver", username: "same@test.com", password: "pw", accountType: .qc),
        ]
        try writePresetsFile(presets)
        defer { removePresetsFile() }

        var accounts = [
            AccountInfo(title: "QA ver", username: "same@test.com", accountType: .qa)
        ]

        let result = useCase.importPresetAccounts(into: &accounts)

        guard case .success(let imported, let skipped) = result else {
            Issue.record("Expected .success")
            return
        }
        #expect(imported == 1)
        #expect(skipped == 0)
    }

    @Test("잘못된 JSON이면 parseError를 반환한다")
    func importPresetsInvalidJSON() throws {
        let dir = PresetAccount.presetsDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "not valid json".data(using: .utf8)!.write(to: PresetAccount.presetsFileURL)
        defer { removePresetsFile() }

        var accounts: [AccountInfo] = []
        let result = useCase.importPresetAccounts(into: &accounts)

        guard case .parseError = result else {
            Issue.record("Expected .parseError, got \(result)")
            return
        }
        #expect(accounts.isEmpty)
    }
}
