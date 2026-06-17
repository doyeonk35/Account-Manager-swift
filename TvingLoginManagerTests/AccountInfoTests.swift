import XCTest
@testable import TvingLoginManager

final class AccountInfoTests: XCTestCase {

    func testAccountTypeDefaultIsQC() {
        let account = AccountInfo(title: "Test", username: "user")
        XCTAssertEqual(account.accountType, .qc)
    }

    func testEncodeExcludesPassword() {
        let account = AccountInfo(title: "A", username: "u", password: "secret123")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(account)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.contains("secret123"))
        XCTAssertFalse(json.contains("password"))
        XCTAssertTrue(json.contains("title"))
        XCTAssertTrue(json.contains("username"))
    }

    func testDecodeRoundTrip() {
        let original = AccountInfo(
            title: "QC Account", username: "testuser",
            accountType: .qa, lastUsed: Date(timeIntervalSince1970: 1700000000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode(AccountInfo.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.username, original.username)
        XCTAssertEqual(decoded.accountType, original.accountType)
        XCTAssertEqual(decoded.password, "")
    }

    func testDecodeFromRustFormatWithPassword() {
        let rustJSON = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "My QC Account",
            "username": "tving_user",
            "password": "old_plain_password",
            "account_type": "QC",
            "last_used": "2026-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let account = try! decoder.decode(AccountInfo.self, from: rustJSON)
        XCTAssertEqual(account.title, "My QC Account")
        XCTAssertEqual(account.accountType, .qc)
        XCTAssertEqual(account.password, "old_plain_password")
    }

    func testLastUsedRelativeJustNow() {
        let account = AccountInfo(title: "T", username: "u", lastUsed: Date())
        let expected = String(localized: "Just now")
        XCTAssertEqual(account.lastUsedRelative, expected)
    }

    func testLastUsedRelativeDaysAgo() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86400)
        let account = AccountInfo(title: "T", username: "u", lastUsed: twoDaysAgo)
        let expected = String(localized: "\(2) days ago")
        XCTAssertEqual(account.lastUsedRelative, expected)
    }

    func testLoginURLForQC() {
        let account = AccountInfo(title: "T", username: "u", accountType: .qc)
        XCTAssertEqual(account.loginURL.absoluteString, "https://user.tving.com/")
    }

    func testLoginURLForQA() {
        let account = AccountInfo(title: "T", username: "u", accountType: .qa)
        XCTAssertEqual(account.loginURL.absoluteString, "https://userqa.tving.com/tv/login/qrcode.tving")
    }
}
