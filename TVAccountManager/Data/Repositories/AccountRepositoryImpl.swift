import Foundation

@MainActor
final class AccountRepositoryImpl: AccountRepository {
    private let storage: StorageService
    private let keychain: KeychainService

    init(storage: StorageService = StorageService(), keychain: KeychainService = KeychainService()) {
        self.storage = storage
        self.keychain = keychain
    }

    func loadAccounts() -> [AccountInfo] {
        storage.loadAccounts()
    }

    func saveAccounts(_ accounts: [AccountInfo]) {
        storage.save(accounts: accounts)
    }

    func loadPassword(forAccountId id: UUID) -> String? {
        keychain.loadPassword(forAccountId: id)
    }

    func savePassword(_ password: String, forAccountId id: UUID) {
        keychain.saveOrUpdate(password: password, forAccountId: id)
    }

    func deletePassword(forAccountId id: UUID) {
        keychain.deletePassword(forAccountId: id)
    }

    func loadProfilePin(forAccountId id: UUID, profileNo: Int) -> String? {
        keychain.load(forKey: KeychainService.profilePinKey(accountId: id, profileNo: profileNo))
    }

    func saveProfilePin(_ pin: String, forAccountId id: UUID, profileNo: Int) {
        keychain.saveOrUpdate(pin, forKey: KeychainService.profilePinKey(accountId: id, profileNo: profileNo))
    }

    func deleteProfilePin(forAccountId id: UUID, profileNo: Int) {
        keychain.delete(forKey: KeychainService.profilePinKey(accountId: id, profileNo: profileNo))
    }
}
