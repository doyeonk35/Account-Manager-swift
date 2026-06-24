import Foundation

struct PresetAccount: Codable {
    let title: String
    let username: String
    let password: String
    let accountType: AccountType
    let planType: PlanType
    let memo: String

    enum CodingKeys: String, CodingKey {
        case title, username, password, memo
        case accountType = "account_type"
        case planType = "plan_type"
    }

    init(
        title: String,
        username: String,
        password: String,
        accountType: AccountType,
        planType: PlanType = .none,
        memo: String = ""
    ) {
        self.title = title
        self.username = username
        self.password = password
        self.accountType = accountType
        self.planType = planType
        self.memo = memo
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
