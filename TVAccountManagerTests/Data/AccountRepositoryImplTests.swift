import Testing
import Foundation
@testable import TVAccountManager

@Suite("AccountRepositoryImpl")
@MainActor
struct AccountRepositoryImplTests {

    let repository: AccountRepositoryImpl
    let tempDir: URL
    let keychain: KeychainService

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        keychain = KeychainService()
        let storage = StorageService(directory: tempDir)
        repository = AccountRepositoryImpl(storage: storage, keychain: keychain)
    }

    // MARK: - Account persistence

    @Test("계정을 저장하고 로드한다")
    func saveAndLoadAccounts() {
        let accounts = [
            AccountInfo(title: "A1", username: "u1", accountType: .qc, planType: .basic),
            AccountInfo(title: "A2", username: "u2", accountType: .qa, planType: .premium),
        ]

        repository.saveAccounts(accounts)
        let loaded = repository.loadAccounts()

        #expect(loaded.count == 2)
        #expect(loaded[0].title == "A1")
        #expect(loaded[0].accountType == .qc)
        #expect(loaded[0].planType == .basic)
        #expect(loaded[1].title == "A2")
        #expect(loaded[1].accountType == .qa)
        #expect(loaded[1].planType == .premium)
    }

    @Test("파일이 없으면 빈 배열을 반환한다")
    func loadAccountsReturnsEmptyWhenNoFile() {
        #expect(repository.loadAccounts().isEmpty)
    }

    @Test("저장 시 이전 데이터를 덮어쓴다")
    func saveOverwritesPrevious() {
        repository.saveAccounts([AccountInfo(title: "First", username: "u1")])
        repository.saveAccounts([AccountInfo(title: "Second", username: "u2")])

        let loaded = repository.loadAccounts()
        #expect(loaded.count == 1)
        #expect(loaded[0].title == "Second")
    }

    @Test("빈 배열 저장으로 데이터를 비운다")
    func saveEmptyArrayClears() {
        repository.saveAccounts([AccountInfo(title: "A", username: "u")])
        repository.saveAccounts([])
        #expect(repository.loadAccounts().isEmpty)
    }

    // MARK: - Password persistence via Keychain

    @Test("비밀번호를 저장하고 로드한다")
    func saveAndLoadPassword() {
        let id = UUID()
        defer { keychain.deletePassword(forAccountId: id) }

        repository.savePassword("myPassword", forAccountId: id)
        #expect(repository.loadPassword(forAccountId: id) == "myPassword")
    }

    @Test("존재하지 않는 비밀번호는 nil을 반환한다")
    func loadPasswordReturnsNilForNonexistent() {
        #expect(repository.loadPassword(forAccountId: UUID()) == nil)
    }

    @Test("비밀번호를 덮어쓴다")
    func savePasswordOverwrites() {
        let id = UUID()
        defer { keychain.deletePassword(forAccountId: id) }

        repository.savePassword("old", forAccountId: id)
        repository.savePassword("new", forAccountId: id)
        #expect(repository.loadPassword(forAccountId: id) == "new")
    }

    @Test("비밀번호를 삭제한다")
    func deletePassword() {
        let id = UUID()

        repository.savePassword("toDelete", forAccountId: id)
        repository.deletePassword(forAccountId: id)
        #expect(repository.loadPassword(forAccountId: id) == nil)
    }

    @Test("없는 비밀번호 삭제는 크래시하지 않는다")
    func deleteNonexistentPasswordIsSafe() {
        repository.deletePassword(forAccountId: UUID())
    }

    // MARK: - Integration

    @Test("계정과 비밀번호를 독립적으로 관리한다")
    func accountsAndPasswordsIndependent() {
        let account = AccountInfo(title: "Test", username: "u")
        let id = account.id
        defer { keychain.deletePassword(forAccountId: id) }

        repository.saveAccounts([account])
        repository.savePassword("pw123", forAccountId: id)

        let loadedAccounts = repository.loadAccounts()
        let loadedPassword = repository.loadPassword(forAccountId: id)

        #expect(loadedAccounts.count == 1)
        #expect(loadedAccounts[0].id == id)
        #expect(loadedPassword == "pw123")
    }

    @Test("모든 PlanType이 영속화를 통과한다")
    func allPlanTypesRoundTrip() {
        let accounts = PlanType.allCases.enumerated().map { index, plan in
            AccountInfo(title: "Plan_\(index)", username: "u\(index)", planType: plan)
        }

        repository.saveAccounts(accounts)
        let loaded = repository.loadAccounts()

        #expect(loaded.count == PlanType.allCases.count)
        for (original, reloaded) in zip(accounts, loaded) {
            #expect(original.planType == reloaded.planType)
        }
    }

    @Test("메모가 특수문자 포함하여 영속화된다")
    func memoWithSpecialCharsRoundTrip() {
        let account = AccountInfo(
            title: "Memo", username: "u",
            memo: "한국어 & émojis 🎉"
        )

        repository.saveAccounts([account])
        let loaded = repository.loadAccounts()

        #expect(loaded[0].memo == account.memo)
    }
}
