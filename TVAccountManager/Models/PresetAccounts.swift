import Foundation

struct PresetAccount: Codable {
    let title: String
    let username: String
    let password: String
    let accountType: AccountType
    let planType: PlanType
    let memo: String
    let profiles: [ProfileInfo]?
    /// profileNo(문자열) → PIN. 비밀번호를 포함해 내보낼 때만 채운다.
    let profilePins: [String: String]?

    enum CodingKeys: String, CodingKey {
        case title, username, password, memo, profiles
        case accountType = "account_type"
        case planType = "plan_type"
        case profilePins = "profile_pins"
    }

    init(
        title: String,
        username: String,
        password: String,
        accountType: AccountType,
        planType: PlanType = .none,
        memo: String = "",
        profiles: [ProfileInfo]? = nil,
        profilePins: [String: String]? = nil
    ) {
        self.title = title
        self.username = username
        self.password = password
        self.accountType = accountType
        self.planType = planType
        self.memo = memo
        self.profiles = profiles
        self.profilePins = profilePins
    }

    /// 형식이 맞는 PIN만 profileNo 키로 돌려준다.
    var validProfilePins: [Int: String] {
        var pins: [Int: String] = [:]
        for (key, pin) in profilePins ?? [:] {
            if let no = Int(key), ProfileInfo.isValidPin(pin) { pins[no] = pin }
        }
        return pins
    }
}

enum PresetLoadResult {
    case success(imported: Int, skipped: Int)
    case fileNotFound
    case parseError(String)
}

extension PresetAccount {
    static let presetsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("tving-login-manager")
    }()

    static let presetsFileURL: URL = {
        presetsDirectory.appendingPathComponent("presets.json")
    }()

    static func loadFromFile() -> Result<[PresetAccount], PresetFileError> {
        let fileURL = presetsFileURL

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .failure(.fileNotFound)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let presets = try decoder.decode([PresetAccount].self, from: data)
            return .success(presets)
        } catch {
            return .failure(.parseError(error.localizedDescription))
        }
    }
}

enum PresetFileError: Error {
    case fileNotFound
    case parseError(String)
}

extension PresetAccount {
    static func generateExampleFileIfNeeded() {
        let exampleURL = presetsDirectory.appendingPathComponent("presets.example.json")
        guard !FileManager.default.fileExists(atPath: exampleURL.path) else { return }

        let examples = [
            PresetAccount(title: "QC 미구독", username: "your_id", password: "your_password", accountType: .qc, planType: .none),
            PresetAccount(title: "QC 베이직", username: "your_id", password: "your_password", accountType: .qc, planType: .basic),
            PresetAccount(title: "QC 광고", username: "your_id", password: "your_password", accountType: .qc, planType: .adSupported),
            PresetAccount(title: "QA 스탠다드", username: "your_id", password: "your_password", accountType: .qa, planType: .standard),
            PresetAccount(title: "QA 프리미엄", username: "your_id", password: "your_password", accountType: .qa, planType: .premium),
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(examples) {
            try? data.write(to: exampleURL)
        }
    }
}

// MARK: - Export

enum PresetExportResult {
    case success(url: URL, count: Int, includedPasswords: Bool)
    case failure(String)
}

extension PresetAccount {
    init(from account: AccountInfo, includePassword: Bool) {
        self.init(
            title: account.title,
            username: account.username,
            password: includePassword ? account.password : "",
            accountType: account.accountType,
            planType: account.planType,
            memo: account.memo,
            profiles: account.profiles.isEmpty ? nil : account.profiles,
            profilePins: includePassword && !account.profilePins.isEmpty
                ? Dictionary(uniqueKeysWithValues: account.profilePins.map { (String($0.key), $0.value) })
                : nil
        )
    }

    /// 초 단위 타임스탬프를 붙여 같은 날 여러 번 내보내도 파일이 겹치지 않는다.
    static func exportFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "accounts-export-\(formatter.string(from: date)).json"
    }

    static func export(
        _ presets: [PresetAccount],
        to directory: URL = presetsDirectory,
        date: Date = Date()
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(presets)

        let url = directory.appendingPathComponent(exportFileName(date: date))
        try data.write(to: url)
        return url
    }
}
