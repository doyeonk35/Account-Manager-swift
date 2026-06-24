import Foundation
@testable import TVAccountManager

@MainActor
final class MockAccountRepository: AccountRepository {
    var storedAccounts: [AccountInfo] = []
    var storedPasswords: [UUID: String] = [:]

    var loadAccountsCallCount = 0
    var saveAccountsCallCount = 0
    var savePasswordCallCount = 0
    var deletePasswordCallCount = 0

    func loadAccounts() -> [AccountInfo] {
        loadAccountsCallCount += 1
        return storedAccounts
    }

    func saveAccounts(_ accounts: [AccountInfo]) {
        saveAccountsCallCount += 1
        storedAccounts = accounts
    }

    func loadPassword(forAccountId id: UUID) -> String? {
        storedPasswords[id]
    }

    func savePassword(_ password: String, forAccountId id: UUID) {
        savePasswordCallCount += 1
        storedPasswords[id] = password
    }

    func deletePassword(forAccountId id: UUID) {
        deletePasswordCallCount += 1
        storedPasswords.removeValue(forKey: id)
    }
}
