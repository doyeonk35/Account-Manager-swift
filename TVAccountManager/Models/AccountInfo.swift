import Foundation

enum AccountType: String, Codable, CaseIterable {
    case qc = "QC"
    case qa = "QA"
}

enum PlanType: String, Codable, CaseIterable {
    case none = "구독 없음"
    case basic = "베이직"
    case adSupported = "광고 요금제"
    case standard = "스탠다드"
    case premium = "프리미엄"

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .basic: String(localized: "Basic")
        case .adSupported: String(localized: "AVOD")
        case .standard: String(localized: "Standard")
        case .premium: String(localized: "Premium")
        }
    }
}

struct AccountInfo: Identifiable {
    let id: UUID
    var title: String
    var username: String
    var password: String      // Memory only — stored in Keychain, NOT in JSON
    var accountType: AccountType
    var planType: PlanType
    var memo: String
    var lastUsed: Date
    var createdAt: Date
    var isPinned: Bool
    var pinnedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        username: String,
        password: String = "",
        accountType: AccountType = .qc,
        planType: PlanType = .none,
        memo: String = "",
        lastUsed: Date = Date(),
        createdAt: Date = Date(),
        isPinned: Bool = false,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.accountType = accountType
        self.planType = planType
        self.memo = memo
        self.lastUsed = lastUsed
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
    }

    static func generateRandomTitle() -> String {
        let adjectives = [
            "Swift", "Brave", "Calm", "Eager", "Fancy",
            "Grand", "Happy", "Jolly", "Lucky", "Noble",
            "Quick", "Sharp", "Vivid", "Warm", "Bold",
            "Bright", "Clever", "Gentle", "Keen", "Proud"
        ]
        let nouns = [
            "Falcon", "Panda", "Tiger", "Eagle", "Whale",
            "Phoenix", "Lion", "Dolphin", "Hawk", "Raven",
            "Wolf", "Fox", "Bear", "Otter", "Crane",
            "Lynx", "Owl", "Stag", "Heron", "Cobra"
        ]
        let adjective = adjectives.randomElement()!
        let noun = nouns.randomElement()!
        let number = Int.random(in: 10...99)
        return "\(adjective)\(noun)\(number)"
    }

    var lastUsedRelative: String {
        let seconds = Int(Date().timeIntervalSince(lastUsed))
        if seconds < 60 { return String(localized: "Just now") }
        if seconds < 3600 { return String(localized: "\(seconds / 60) minutes ago") }
        if seconds < 86400 { return String(localized: "\(seconds / 3600) hours ago") }
        return String(localized: "\(seconds / 86400) days ago")
    }

}

// MARK: - Codable (password excluded from encoding, but readable for Rust migration)
extension AccountInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, username, password, memo
        case accountType = "account_type"
        case planType = "plan_type"
        case lastUsed = "last_used"
        case createdAt = "created_at"
        case isPinned = "is_pinned"
        case pinnedAt = "pinned_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(username, forKey: .username)
        // password intentionally NOT encoded — stored in Keychain
        try container.encode(accountType, forKey: .accountType)
        try container.encode(planType, forKey: .planType)
        try container.encode(memo, forKey: .memo)
        try container.encode(lastUsed, forKey: .lastUsed)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encodeIfPresent(pinnedAt, forKey: .pinnedAt)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        username = try container.decode(String.self, forKey: .username)
        // Migration: read password from Rust JSON if present, otherwise empty
        password = (try? container.decode(String.self, forKey: .password)) ?? ""
        accountType = try container.decode(AccountType.self, forKey: .accountType)
        // Migration: plan_type이 없는 기존 JSON 호환
        planType = (try? container.decode(PlanType.self, forKey: .planType)) ?? .basic
        memo = (try? container.decode(String.self, forKey: .memo)) ?? ""
        lastUsed = try container.decode(Date.self, forKey: .lastUsed)
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? lastUsed
        isPinned = (try? container.decode(Bool.self, forKey: .isPinned)) ?? false
        pinnedAt = try? container.decode(Date.self, forKey: .pinnedAt)
    }
}
