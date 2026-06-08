import Foundation

enum AccountType: String, Codable, CaseIterable {
    case qc = "QC"
    case qa = "QA"
}

struct AccountInfo: Identifiable {
    let id: UUID
    var title: String
    var username: String
    var password: String      // Memory only — stored in Keychain, NOT in JSON
    var accountType: AccountType
    var lastUsed: Date

    init(
        id: UUID = UUID(),
        title: String,
        username: String,
        password: String = "",
        accountType: AccountType = .qc,
        lastUsed: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.accountType = accountType
        self.lastUsed = lastUsed
    }

    var lastUsedRelative: String {
        let seconds = Int(Date().timeIntervalSince(lastUsed))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60) minutes ago" }
        if seconds < 86400 { return "\(seconds / 3600) hours ago" }
        return "\(seconds / 86400) days ago"
    }

    var loginURL: URL {
        switch accountType {
        case .qc: URL(string: "https://user.tving.com/")!
        case .qa: URL(string: "https://userqa.tving.com/tv/login/qrcode.tving")!
        }
    }
}

// MARK: - Codable (password excluded from encoding, but readable for Rust migration)
extension AccountInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, username, password
        case accountType = "account_type"
        case lastUsed = "last_used"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(username, forKey: .username)
        // password intentionally NOT encoded — stored in Keychain
        try container.encode(accountType, forKey: .accountType)
        try container.encode(lastUsed, forKey: .lastUsed)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        username = try container.decode(String.self, forKey: .username)
        // Migration: read password from Rust JSON if present, otherwise empty
        password = (try? container.decode(String.self, forKey: .password)) ?? ""
        accountType = try container.decode(AccountType.self, forKey: .accountType)
        lastUsed = try container.decode(Date.self, forKey: .lastUsed)
    }
}
