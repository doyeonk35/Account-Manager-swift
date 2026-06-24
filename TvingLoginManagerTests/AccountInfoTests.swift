import Testing
import Foundation
@testable import TvingLoginManager

@Suite("AccountInfo")
struct AccountInfoTests {

    @Test("기본 AccountType은 QC이다")
    func accountTypeDefaultIsQC() {
        let account = AccountInfo(title: "Test", username: "user")
        #expect(account.accountType == .qc)
    }

    @Test("인코딩 시 비밀번호를 제외한다")
    func encodeExcludesPassword() throws {
        let account = AccountInfo(title: "A", username: "u", password: "secret123")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(account)
        let json = String(data: data, encoding: .utf8)!
        #expect(!json.contains("secret123"))
        #expect(!json.contains("password"))
        #expect(json.contains("title"))
        #expect(json.contains("username"))
    }

    @Test("인코딩/디코딩 라운드트립이 정상 동작한다")
    func decodeRoundTrip() throws {
        let original = AccountInfo(
            title: "QC Account", username: "testuser",
            accountType: .qa, lastUsed: Date(timeIntervalSince1970: 1700000000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AccountInfo.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.username == original.username)
        #expect(decoded.accountType == original.accountType)
        #expect(decoded.password == "")
    }

    @Test("Rust 포맷 JSON에서 비밀번호를 읽는다")
    func decodeFromRustFormatWithPassword() throws {
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
        let account = try decoder.decode(AccountInfo.self, from: rustJSON)
        #expect(account.title == "My QC Account")
        #expect(account.accountType == .qc)
        #expect(account.password == "old_plain_password")
    }

    @Test("방금 사용한 계정은 'Just now'을 반환한다")
    func lastUsedRelativeJustNow() {
        let account = AccountInfo(title: "T", username: "u", lastUsed: Date())
        let expected = String(localized: "Just now")
        #expect(account.lastUsedRelative == expected)
    }

    @Test("2일 전 계정은 '2 days ago'를 반환한다")
    func lastUsedRelativeDaysAgo() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86400)
        let account = AccountInfo(title: "T", username: "u", lastUsed: twoDaysAgo)
        let expected = String(localized: "\(2) days ago")
        #expect(account.lastUsedRelative == expected)
    }

}
