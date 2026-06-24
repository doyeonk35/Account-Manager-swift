import Foundation

typealias AccountStore = Store<AccountState, AccountAction>

struct AccountState {
    var accounts: [AccountInfo] = []
    var selectedAccountId: UUID?

    // Edit form
    var isEditing = false
    var editingAccountId: UUID?
    var editTitle = ""
    var editUsername = ""
    var editPassword = ""
    var editAccountType: AccountType = .qc
    var editPlanType: PlanType = .none
    var editMemo = ""

    // Login
    var loginStatus = ""
    var isLoggingIn = false
    var otpCode = ""
    var showLoginWebView = false
    var loginAccount: AccountInfo?

    // Delete confirmation
    var accountToDelete: AccountInfo?

    var isEditFormValid: Bool {
        !editUsername.isEmpty && !editPassword.isEmpty
    }
}

enum AccountAction: Sendable {
    // Data
    case load
    case delete(UUID)
    case confirmDelete(AccountInfo)
    case cancelDelete

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

    // Login
    case startLogin(AccountInfo)
    case loginCompleted(success: Bool, message: String)
    case cancelLogin
    case dismissLoginWebView
    case setOtpCode(String)
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

            // MARK: - Edit Form

            case .startAdding:
                state.editingAccountId = nil
                state.editTitle = String(localized: "title(Untitled)")
                state.editUsername = ""
                state.editPassword = ""
                state.editAccountType = .qc
                state.editPlanType = .basic
                state.editMemo = ""
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
                        planType: state.editPlanType, memo: state.editMemo
                    )
                } else {
                    useCase.addAccount(
                        to: &state.accounts,
                        title: state.editTitle, username: state.editUsername,
                        password: state.editPassword, accountType: state.editAccountType,
                        planType: state.editPlanType, memo: state.editMemo
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
            }
        }
    }
}
