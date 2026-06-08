import XCTest
@testable import TvingLoginManager

@MainActor
final class AccountManagerTests: XCTestCase {

    var manager: AccountManager!
    var tempDir: URL!
    var keychain: KeychainService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        keychain = KeychainService()
        let storage = StorageService(directory: tempDir)
        manager = AccountManager(storage: storage, keychain: keychain)
    }

    override func tearDown() {
        for account in manager.accounts {
            keychain.deletePassword(forAccountId: account.id)
        }
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testAddAccount() {
        manager.addAccount(title: "Test", username: "u", password: "p", accountType: .qc)
        XCTAssertEqual(manager.accounts.count, 1)
        XCTAssertEqual(manager.accounts[0].title, "Test")
        let stored = keychain.loadPassword(forAccountId: manager.accounts[0].id)
        XCTAssertEqual(stored, "p")
    }

    func testUpdateAccount() {
        manager.addAccount(title: "Old", username: "u", password: "oldpw", accountType: .qc)
        let id = manager.accounts[0].id
        manager.updateAccount(id: id, title: "New", username: "u2", password: "newpw", accountType: .qa)
        XCTAssertEqual(manager.accounts[0].title, "New")
        XCTAssertEqual(manager.accounts[0].accountType, .qa)
        XCTAssertEqual(keychain.loadPassword(forAccountId: id), "newpw")
    }

    func testDeleteAccount() {
        manager.addAccount(title: "A", username: "u", password: "pw", accountType: .qc)
        let id = manager.accounts[0].id
        manager.deleteAccount(id: id)
        XCTAssertTrue(manager.accounts.isEmpty)
        XCTAssertNil(keychain.loadPassword(forAccountId: id))
    }

    func testDeleteSelectedAccountClearsSelection() {
        manager.addAccount(title: "A", username: "u", password: "p", accountType: .qc)
        let id = manager.accounts[0].id
        manager.selectedAccountId = id
        manager.deleteAccount(id: id)
        XCTAssertNil(manager.selectedAccountId)
    }

    func testEditFormValidation() {
        manager.editTitle = ""
        manager.editUsername = ""
        manager.editPassword = ""
        XCTAssertFalse(manager.isEditFormValid)
        manager.editTitle = "T"
        manager.editUsername = "U"
        manager.editPassword = "P"
        XCTAssertTrue(manager.isEditFormValid)
    }

    func testMigrationFromRustJSON() {
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

        XCTAssertEqual(migratedManager.accounts.count, 1)
        XCTAssertEqual(migratedManager.accounts[0].title, "Rust Acct")

        let accountId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        XCTAssertEqual(keychain.loadPassword(forAccountId: accountId), "rust_password")

        let reloadedJSON = try! String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(reloadedJSON.contains("rust_password"))

        // Cleanup migrated keychain entry
        keychain.deletePassword(forAccountId: accountId)
    }
}
