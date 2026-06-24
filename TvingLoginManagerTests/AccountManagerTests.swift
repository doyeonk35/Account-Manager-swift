import Testing
import Foundation
@testable import TvingLoginManager

@Suite("AccountManager")
@MainActor
struct AccountManagerTests {

    let manager: AccountManager
    let keychain: KeychainService
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        keychain = KeychainService()
        let storage = StorageService(directory: tempDir)
        manager = AccountManager(storage: storage, keychain: keychain)
    }

    @Test("계정을 추가한다")
    func addAccount() {
        manager.addAccount(title: "Test", username: "u", password: "p", accountType: .qc, planType: .basic, memo: "")
        #expect(manager.accounts.count == 1)
        #expect(manager.accounts[0].title == "Test")
        let stored = keychain.loadPassword(forAccountId: manager.accounts[0].id)
        #expect(stored == "p")
        keychain.deletePassword(forAccountId: manager.accounts[0].id)
    }

    @Test("계정을 수정한다")
    func updateAccount() {
        manager.addAccount(title: "Old", username: "u", password: "oldpw", accountType: .qc, planType: .basic, memo: "")
        let id = manager.accounts[0].id
        manager.updateAccount(id: id, title: "New", username: "u2", password: "newpw", accountType: .qa, planType: .standard, memo: "updated")
        #expect(manager.accounts[0].title == "New")
        #expect(manager.accounts[0].accountType == .qa)
        #expect(keychain.loadPassword(forAccountId: id) == "newpw")
        keychain.deletePassword(forAccountId: id)
    }

    @Test("계정을 삭제한다")
    func deleteAccount() {
        manager.addAccount(title: "A", username: "u", password: "pw", accountType: .qc, planType: .basic, memo: "")
        let id = manager.accounts[0].id
        manager.deleteAccount(id: id)
        #expect(manager.accounts.isEmpty)
        #expect(keychain.loadPassword(forAccountId: id) == nil)
    }

    @Test("선택된 계정을 삭제하면 선택이 해제된다")
    func deleteSelectedAccountClearsSelection() {
        manager.addAccount(title: "A", username: "u", password: "p", accountType: .qc, planType: .basic, memo: "")
        let id = manager.accounts[0].id
        manager.selectedAccountId = id
        manager.deleteAccount(id: id)
        #expect(manager.selectedAccountId == nil)
    }

    @Test("편집 폼 유효성 검증")
    func editFormValidation() {
        manager.editTitle = ""
        manager.editUsername = ""
        manager.editPassword = ""
        #expect(manager.isEditFormValid == false)
        manager.editUsername = "U"
        manager.editPassword = "P"
        #expect(manager.isEditFormValid == true)
    }

    @Test("Rust JSON에서 마이그레이션한다")
    func migrationFromRustJSON() {
        let rustJSON = """
        [{
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "Rust Acct",
            "username": "rust_user",
            "password": "rust_password",
            "account_type": "QC",
            "last_used": "2026-01-15T10:30:00Z"
        }]
        """
        let fileURL = tempDir.appendingPathComponent("accounts.json")
        try! rustJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        let storage = StorageService(directory: tempDir)
        let migratedManager = AccountManager(storage: storage, keychain: keychain)

        #expect(migratedManager.accounts.count == 1)
        #expect(migratedManager.accounts[0].title == "Rust Acct")

        let accountId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        #expect(keychain.loadPassword(forAccountId: accountId) == "rust_password")

        let reloadedJSON = try! String(contentsOf: fileURL, encoding: .utf8)
        #expect(!reloadedJSON.contains("rust_password"))

        keychain.deletePassword(forAccountId: accountId)
    }
}
