import Foundation
import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case accounts = "Accounts"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .accounts: "person.2"
        case .settings: "gearshape"
        }
    }
}

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
    @Published var editPlanType: PlanType = .basic

    // Login state
    @Published var loginStatus = ""
    @Published var isLoggingIn = false
    @Published var otpCode = ""

    // Login WebView
    @Published var showLoginWebView = false
    @Published var loginAccount: AccountInfo?

    // Delete confirmation
    @Published var accountToDelete: AccountInfo?

    // Custom login URLs (persisted via UserDefaults)
    @AppStorage("loginURL_QC") var qcLoginURL = "https://user.tving.com/"
    @AppStorage("loginURL_QA") var qaLoginURL = "https://userqa.tving.com/tv/login/qrcode.tving"

    // Sidebar
    @Published var selectedTab: SidebarTab = .accounts

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

    func addAccount(title: String, username: String, password: String, accountType: AccountType, planType: PlanType) {
        let account = AccountInfo(
            title: title, username: username, password: password, accountType: accountType, planType: planType
        )
        keychain.saveOrUpdate(password: password, forAccountId: account.id)
        accounts.append(account)
        storage.save(accounts: accounts)
    }

    func updateAccount(id: UUID, title: String, username: String, password: String, accountType: AccountType, planType: PlanType) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].title = title
        accounts[index].username = username
        accounts[index].password = password
        accounts[index].accountType = accountType
        accounts[index].planType = planType
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
        editPlanType = .basic
        isEditing = true
    }

    func startEditing(account: AccountInfo) {
        editingAccountId = account.id
        editTitle = account.title
        editUsername = account.username
        editPassword = account.password
        editAccountType = account.accountType
        editPlanType = account.planType
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        editingAccountId = nil
    }

    func saveEdit() {
        if let id = editingAccountId {
            updateAccount(id: id, title: editTitle, username: editUsername,
                         password: editPassword, accountType: editAccountType, planType: editPlanType)
        } else {
            addAccount(title: editTitle, username: editUsername,
                      password: editPassword, accountType: editAccountType, planType: editPlanType)
        }
        isEditing = false
        editingAccountId = nil
    }

    var isEditFormValid: Bool {
        !editTitle.isEmpty && !editUsername.isEmpty && !editPassword.isEmpty
    }

    // MARK: - Login

    /// 계정 타입에 맞는 커스텀 로그인 URL 반환
    func loginURL(for accountType: AccountType) -> URL {
        switch accountType {
        case .qc: URL(string: qcLoginURL) ?? URL(string: "https://user.tving.com/")!
        case .qa: URL(string: qaLoginURL) ?? URL(string: "https://userqa.tving.com/tv/login/qrcode.tving")!
        }
    }

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
