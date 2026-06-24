import Foundation

typealias AccountStore = Store<AccountState, AccountAction>

enum AccountFilterTab: String, CaseIterable {
    case all
    case qc
    case qa
    case pinned

    var displayName: String {
        switch self {
        case .all: String(localized: "All")
        case .qc: "QC"
        case .qa: "QA"
        case .pinned: String(localized: "Favorites")
        }
    }
}

enum AccountSortField: String, CaseIterable {
    case name
    case username
    case plan
    case createdAt
    case accountType

    var displayName: String {
        switch self {
        case .name: String(localized: "Name")
        case .username: String(localized: "ID")
        case .plan: String(localized: "Subscribe Plan")
        case .createdAt: String(localized: "Date Added")
        case .accountType: String(localized: "Env Type")
        }
    }
}

enum PlanSortIndex {
    static func index(of plan: PlanType) -> Int {
        switch plan {
        case .none: 0
        case .adSupported: 1
        case .basic: 2
        case .standard: 3
        case .premium: 4
        }
    }
}

struct AccountState {
    var accounts: [AccountInfo] = []
    var selectedAccountId: UUID?
    var filterTab: AccountFilterTab = .all
    var sortField: AccountSortField = .name
    var sortAscending = true

    // Edit form
    var isEditing = false
    var editingAccountId: UUID?
    var editTitle = ""
    var editUsername = ""
    var editPassword = ""
    var editAccountType: AccountType = .qc
    var editPlanType: PlanType = .none
    var editMemo = ""
    var editIsPinned = false

    // Login
    var loginStatus = ""
    var isLoggingIn = false
    var otpCode = ""
    var showLoginWebView = false
    var loginAccount: AccountInfo?

    // Delete confirmation
    var accountToDelete: AccountInfo?

    // Preset import result
    var importResult: PresetLoadResult?

    var isEditFormValid: Bool {
        !editUsername.isEmpty && !editPassword.isEmpty
    }

    var sortedAccounts: [AccountInfo] {
        let filtered: [AccountInfo]
        switch filterTab {
        case .all: filtered = accounts
        case .qc: filtered = accounts.filter { $0.accountType == .qc }
        case .qa: filtered = accounts.filter { $0.accountType == .qa }
        case .pinned: filtered = accounts.filter(\.isPinned)
        }

        let pinned = filtered.filter(\.isPinned).sorted {
            ($0.pinnedAt ?? .distantPast) < ($1.pinnedAt ?? .distantPast)
        }
        let unpinned = filtered.filter { !$0.isPinned }.sorted { a, b in
            let result = fieldCompare(a, b)
            return sortAscending ? result : !result
        }
        return pinned + unpinned
    }

    private func fieldCompare(_ a: AccountInfo, _ b: AccountInfo) -> Bool {
        switch sortField {
        case .name:
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        case .username:
            return a.username.localizedCaseInsensitiveCompare(b.username) == .orderedAscending
        case .plan:
            let ai = PlanSortIndex.index(of: a.planType)
            let bi = PlanSortIndex.index(of: b.planType)
            if ai != bi { return ai < bi }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        case .createdAt:
            return a.createdAt < b.createdAt
        case .accountType:
            if a.accountType != b.accountType { return a.accountType.rawValue < b.accountType.rawValue }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    var pinnedCount: Int {
        accounts.filter(\.isPinned).count
    }
}

enum AccountAction: Sendable {
    // Data
    case load
    case delete(UUID)
    case confirmDelete(AccountInfo)
    case cancelDelete

    // Filter & Sort
    case setFilterTab(AccountFilterTab)
    case setSortField(AccountSortField)
    case toggleSortDirection

    // Edit form
    case startAdding
    case startEditing(AccountInfo)
    case cancelEditing
    case saveEdit
    case setEditTitle(String)
    case setEditUsername(String)
    case setEditPassword(String)
    case setEditAccountType(AccountType)
    case setEditPlanType(PlanType)
    case setEditMemo(String)
    case setEditIsPinned(Bool)

    // Login
    case startLogin(AccountInfo)
    case loginCompleted(success: Bool, message: String)
    case cancelLogin
    case dismissLoginWebView
    case setOtpCode(String)

    // Preset import
    case importPresets
    case dismissImportResult
}

enum AccountEnvironment {
    @MainActor
    static func reducer(useCase: AccountUseCase) -> @MainActor (inout AccountState, AccountAction) -> Effect<AccountAction> {
        { state, action in
            switch action {

            // MARK: - Data

            case .load:
                state.accounts = useCase.loadAccounts()
                return .none

            case .delete(let id):
                useCase.deleteAccount(from: &state.accounts, id: id)
                if state.selectedAccountId == id { state.selectedAccountId = nil }
                state.accountToDelete = nil
                return .none

            case .confirmDelete(let account):
                state.accountToDelete = account
                return .none

            case .cancelDelete:
                state.accountToDelete = nil
                return .none

            // MARK: - Filter & Sort

            case .setFilterTab(let tab):
                state.filterTab = tab
                return .none

            case .setSortField(let field):
                state.sortField = field
                return .none

            case .toggleSortDirection:
                state.sortAscending.toggle()
                return .none

            // MARK: - Edit Form

            case .startAdding:
                state.editingAccountId = nil
                state.editTitle = String(localized: "title(Untitled)")
                state.editUsername = ""
                state.editPassword = ""
                state.editAccountType = .qc
                state.editPlanType = .basic
                state.editMemo = ""
                state.editIsPinned = false
                state.isEditing = true
                return .none

            case .startEditing(let account):
                state.editingAccountId = account.id
                state.editTitle = account.title
                state.editUsername = account.username
                state.editPassword = account.password
                state.editAccountType = account.accountType
                state.editPlanType = account.planType
                state.editMemo = account.memo
                state.editIsPinned = account.isPinned
                state.isEditing = true
                return .none

            case .cancelEditing:
                state.isEditing = false
                state.editingAccountId = nil
                return .none

            case .saveEdit:
                if let id = state.editingAccountId {
                    useCase.updateAccount(
                        in: &state.accounts, id: id,
                        title: state.editTitle, username: state.editUsername,
                        password: state.editPassword, accountType: state.editAccountType,
                        planType: state.editPlanType, memo: state.editMemo,
                        isPinned: state.editIsPinned
                    )
                } else {
                    useCase.addAccount(
                        to: &state.accounts,
                        title: state.editTitle, username: state.editUsername,
                        password: state.editPassword, accountType: state.editAccountType,
                        planType: state.editPlanType, memo: state.editMemo,
                        isPinned: state.editIsPinned
                    )
                }
                state.isEditing = false
                state.editingAccountId = nil
                return .none

            case .setEditTitle(let value):
                state.editTitle = value
                return .none

            case .setEditUsername(let value):
                state.editUsername = value
                return .none

            case .setEditPassword(let value):
                state.editPassword = value
                return .none

            case .setEditAccountType(let value):
                state.editAccountType = value
                return .none

            case .setEditPlanType(let value):
                state.editPlanType = value
                return .none

            case .setEditMemo(let value):
                let trimmed = value.count > 250 ? String(value.prefix(250)) : value
                state.editMemo = trimmed
                return .none

            case .setEditIsPinned(let value):
                if value && !state.editIsPinned {
                    let currentPinCount = state.pinnedCount
                    let isEditingAlreadyPinned = state.editingAccountId.flatMap { id in
                        state.accounts.first { $0.id == id }
                    }?.isPinned ?? false
                    let effectiveCount = isEditingAlreadyPinned ? currentPinCount - 1 : currentPinCount
                    guard effectiveCount < 2 else { return .none }
                }
                state.editIsPinned = value
                return .none

            // MARK: - Login

            case .startLogin(let account):
                guard !state.isLoggingIn else { return .none }
                state.isLoggingIn = true
                state.loginStatus = String(localized: "Logging in...")
                state.selectedAccountId = account.id

                var loginTarget = account
                loginTarget.password = useCase.loadPassword(forAccountId: account.id) ?? account.password
                state.loginAccount = loginTarget
                state.showLoginWebView = true
                return .none

            case .loginCompleted(let success, let message):
                state.isLoggingIn = false
                state.loginStatus = message
                if success, let id = state.loginAccount?.id {
                    useCase.markUsed(in: &state.accounts, id: id)
                }
                return .none

            case .cancelLogin:
                state.isLoggingIn = false
                state.loginStatus = String(localized: "Login cancelled.")
                state.showLoginWebView = false
                state.loginAccount = nil
                return .none

            case .dismissLoginWebView:
                state.showLoginWebView = false
                state.loginAccount = nil
                return .none

            case .setOtpCode(let value):
                state.otpCode = value
                return .none

            // MARK: - Preset Import

            case .importPresets:
                let result = useCase.importPresetAccounts(into: &state.accounts)
                state.importResult = result
                return .none

            case .dismissImportResult:
                state.importResult = nil
                return .none
            }
        }
    }
}
