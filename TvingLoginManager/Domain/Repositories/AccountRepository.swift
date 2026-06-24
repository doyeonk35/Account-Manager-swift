import Foundation

@MainActor
protocol AccountRepository: Sendable {
    func loadAccounts() -> [AccountInfo]
    func saveAccounts(_ accounts: [AccountInfo])
    func loadPassword(forAccountId id: UUID) -> String?
    func savePassword(_ password: String, forAccountId id: UUID)
    func deletePassword(forAccountId id: UUID)
}
