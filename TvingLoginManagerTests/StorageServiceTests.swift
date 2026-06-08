import XCTest
@testable import TvingLoginManager

final class StorageServiceTests: XCTestCase {

    var service: StorageService!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = StorageService(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoad() {
        let accounts = [
            AccountInfo(title: "A1", username: "u1", accountType: .qc),
            AccountInfo(title: "A2", username: "u2", accountType: .qa),
        ]
        service.save(accounts: accounts)
        let loaded = service.loadAccounts()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].title, "A1")
        XCTAssertEqual(loaded[1].accountType, .qa)
    }

    func testSavedJSONDoesNotContainPassword() {
        let accounts = [AccountInfo(title: "A", username: "u", password: "secret")]
        service.save(accounts: accounts)

        let fileURL = tempDir.appendingPathComponent("accounts.json")
        let json = try! String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertFalse(json.contains("secret"))
        XCTAssertFalse(json.contains("password"))
    }

    func testLoadFromEmptyReturnsEmpty() {
        XCTAssertTrue(service.loadAccounts().isEmpty)
    }

    func testLoadCorruptedFileReturnsEmpty() {
        let fileURL = tempDir.appendingPathComponent("accounts.json")
        try! "not valid json".write(to: fileURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(service.loadAccounts().isEmpty)
    }

    func testLoadRustFormatWithPasswordField() {
        let rustJSON = """
        [{
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "Rust Account",
            "username": "rust_user",
            "password": "plain_text_pw",
            "account_type": "QC",
            "last_used": "2026-01-15T10:30:00Z"
        }]
        """
        let fileURL = tempDir.appendingPathComponent("accounts.json")
        try! rustJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        let loaded = service.loadAccounts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Rust Account")
        XCTAssertEqual(loaded[0].password, "plain_text_pw")
    }
}
