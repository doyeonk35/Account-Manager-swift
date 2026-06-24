import Testing
import Foundation
@testable import TVAccountManager

@Suite("StorageService")
struct StorageServiceTests {

    let service: StorageService
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = StorageService(directory: tempDir)
    }

    @Test("계정을 저장하고 로드한다")
    func saveAndLoad() {
        let accounts = [
            AccountInfo(title: "A1", username: "u1", accountType: .qc),
            AccountInfo(title: "A2", username: "u2", accountType: .qa),
        ]
        service.save(accounts: accounts)
        let loaded = service.loadAccounts()

        #expect(loaded.count == 2)
        #expect(loaded[0].title == "A1")
        #expect(loaded[1].accountType == .qa)
    }

    @Test("저장된 JSON에 비밀번호가 포함되지 않는다")
    func savedJSONDoesNotContainPassword() {
        let accounts = [AccountInfo(title: "A", username: "u", password: "secret")]
        service.save(accounts: accounts)

        let fileURL = tempDir.appendingPathComponent("accounts.json")
        let json = try! String(contentsOf: fileURL, encoding: .utf8)

        #expect(!json.contains("secret"))
        #expect(!json.contains("password"))
    }

    @Test("빈 디렉토리에서 빈 배열을 반환한다")
    func loadFromEmptyReturnsEmpty() {
        #expect(service.loadAccounts().isEmpty)
    }

    @Test("손상된 파일에서 빈 배열을 반환한다")
    func loadCorruptedFileReturnsEmpty() {
        let fileURL = tempDir.appendingPathComponent("accounts.json")
        try! "not valid json".write(to: fileURL, atomically: true, encoding: .utf8)
        #expect(service.loadAccounts().isEmpty)
    }

    @Test("Rust 포맷 JSON에서 비밀번호 필드를 읽는다")
    func loadRustFormatWithPasswordField() {
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
        #expect(loaded.count == 1)
        #expect(loaded[0].title == "Rust Account")
        #expect(loaded[0].password == "plain_text_pw")
    }
}
