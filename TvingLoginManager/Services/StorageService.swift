import Foundation

final class StorageService {
    private let fileURL: URL

    /// Production: ~/Library/Application Support/tving-login-manager/
    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("tving-login-manager")

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.fileURL = appSupport.appendingPathComponent("accounts.json")
    }

    /// Test: custom directory
    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("accounts.json")
    }

    func loadAccounts() -> [AccountInfo] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([AccountInfo].self, from: data)
        } catch {
            print("Failed to load accounts: \(error)")
            return []
        }
    }

    func save(accounts: [AccountInfo]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(accounts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save accounts: \(error)")
        }
    }
}
