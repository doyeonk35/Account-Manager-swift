import Foundation
import SwiftUI

@MainActor
final class AccountManager: ObservableObject {

    @Published var accounts: [AccountInfo] = []
    @Published var selectedAccountId: UUID?

    // Edit state
    @Published var isEditing = false
    @Published var editingAccountId: UUID?
    @Published var editTitle = ""
    @Published var editUsername = ""
    @Published var editPassword = ""
    @Published var editAccountType: AccountType = .qc

    // Login state
    @Published var loginStatus = ""
    @Published var isLoggingIn = false
    @Published var otpCode = ""

    // Login WebView
    @Published var showLoginWebView = false
    @Published var loginAccount: AccountInfo?

    // Delete confirmation
    @Published var accountToDelete: AccountInfo?

    private let storage: StorageService
    private let keychain: KeychainService

    init(storage: StorageService = StorageService(), keychain: KeychainService = KeychainService()) {
        self.storage = storage
        self.keychain = keychain
        loadAndMigrate()
    }

    /// Load accounts from JSON. If Rust JSON has passwords, migrate to Keychain.
    private func loadAndMigrate() {
        var loaded = storage.loadAccounts()
        var needsResave = false

        for i in loaded.indices {
            if !loaded[i].password.isEmpty {
                // Rust JSON plaintext password → Keychain
                keychain.saveOrUpdate(password: loaded[i].password, forAccountId: loaded[i].id)
                loaded[i].password = ""
                needsResave = true
            } else {
                // Load password from Keychain (memory only)
                loaded[i].password = keychain.loadPassword(forAccountId: loaded[i].id) ?? ""
            }
        }

        accounts = loaded

        if needsResave {
            storage.save(accounts: accounts)
        }
    }

    // MARK: - CRUD

    func addAccount(title: String, username: String, password: String, accountType: AccountType) {
        let account = AccountInfo(
            title: title, username: username, password: password, accountType: accountType
        )
        keychain.saveOrUpdate(password: password, forAccountId: account.id)
        accounts.append(account)
        storage.save(accounts: accounts)
    }

    func updateAccount(id: UUID, title: String, username: String, password: String, accountType: AccountType) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].title = title
        accounts[index].username = username
        accounts[index].password = password
        accounts[index].accountType = accountType
        keychain.saveOrUpdate(password: password, forAccountId: id)
        storage.save(accounts: accounts)
    }

    func deleteAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        keychain.deletePassword(forAccountId: id)
        if selectedAccountId == id { selectedAccountId = nil }
        storage.save(accounts: accounts)
    }

    // MARK: - Edit Form

    func startAdding() {
        editingAccountId = nil
        editTitle = ""
        editUsername = ""
        editPassword = ""
        editAccountType = .qc
        isEditing = true
    }

    func startEditing(account: AccountInfo) {
        editingAccountId = account.id
        editTitle = account.title
        editUsername = account.username
        editPassword = account.password
        editAccountType = account.accountType
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        editingAccountId = nil
    }

    func saveEdit() {
        if let id = editingAccountId {
            updateAccount(id: id, title: editTitle, username: editUsername,
                         password: editPassword, accountType: editAccountType)
        } else {
            addAccount(title: editTitle, username: editUsername,
                      password: editPassword, accountType: editAccountType)
        }
        isEditing = false
        editingAccountId = nil
    }

    var isEditFormValid: Bool {
        !editTitle.isEmpty && !editUsername.isEmpty && !editPassword.isEmpty
    }

    // MARK: - Login

    func startLogin(account: AccountInfo) {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        loginStatus = "Logging in..."
        selectedAccountId = account.id

        var loginTarget = account
        loginTarget.password = keychain.loadPassword(forAccountId: account.id) ?? account.password

        loginAccount = loginTarget
        showLoginWebView = true
    }

    func loginCompleted(success: Bool, message: String) {
        isLoggingIn = false
        loginStatus = message

        if success, let id = loginAccount?.id,
           let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].lastUsed = Date()
            storage.save(accounts: accounts)
        }
    }

    func dismissLoginWebView() {
        showLoginWebView = false
        loginAccount = nil
    }
}
