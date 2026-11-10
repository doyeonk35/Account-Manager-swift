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
    var editProfilePins: [Int: String] = [:]   // profileNo → PIN (빈 값 = 삭제)

    // Login
    var loginStatus = ""
    var isLoggingIn = false
    var otpCode = ""
    var showLoginWebView = false
    var loginAccount: AccountInfo?
    var backgroundLoginAccountId: UUID?
    /// 진행 중인 메뉴바 로그인 실행 id — 늦게 도착한 이전 실행의 결과를 걸러낸다
    var backgroundLoginRunId: UUID?
    /// 백그라운드 로그인이 사람 손을 필요로 끝난 계정 — 메뉴바가 "창에서 로그인"을 제안한다
    var windowLoginFallbackId: UUID?

    // Delete confirmation
    var accountToDelete: AccountInfo?

    // Preset import result
    var importResult: PresetLoadResult?

    // Export
    var isConfirmingExport = false
    var exportResult: PresetExportResult?

    var selectedAccount: AccountInfo? {
        guard let id = selectedAccountId else { return nil }
        return accounts.first { $0.id == id }
    }

    var isEditFormValid: Bool {
        !editUsername.isEmpty && !editPassword.isEmpty
            && editingProfiles.filter(\.isLocked).allSatisfy {
                let pin = editProfilePins[$0.profileNo] ?? ""
                return pin.isEmpty || ProfileInfo.isValidPin(pin)
            }
    }

    /// 편집 중인 기존 계정의 프로필. 새 계정이면 비어 있다.
    var editingProfiles: [ProfileInfo] {
        guard let id = editingAccountId else { return [] }
        return accounts.first { $0.id == id }?.profiles ?? []
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

    /// 메뉴바에 보일 계정 (최대 3개): 고정 계정을 고정한 순서대로 먼저, 남는 자리는 최근 사용 순.
    var menuBarAccounts: [AccountInfo] {
        let pinned = accounts.filter(\.isPinned).sorted {
            ($0.pinnedAt ?? .distantPast) < ($1.pinnedAt ?? .distantPast)
        }
        let recent = accounts.filter { !$0.isPinned }.sorted { $0.lastUsed > $1.lastUsed }
        return Array((pinned + recent).prefix(3))
    }

    var exportedFileURL: URL? {
        guard case .success(let url, _, _) = exportResult else { return nil }
        return url
    }
}

enum AccountAction: Sendable {
    // Data
    case load
    case delete(UUID)
    case confirmDelete(AccountInfo)
    case cancelDelete

    // Selection
    case selectAccount(UUID?)

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
    case setEditProfilePin(profileNo: Int, pin: String)

    // Login
    case startLogin(AccountInfo)
    case loginCompleted(success: Bool, message: String)
    case cancelLogin
    case dismissLoginWebView
    case setOtpCode(String)
    case profilesCollected(accountId: UUID, profiles: [ProfileInfo])

    // Menu bar (창 없이 백그라운드 로그인)
    case startBackgroundLogin(AccountInfo)
    case backgroundLoginFinished(runId: UUID, accountId: UUID, outcome: LoginOutcome, message: String, profiles: [ProfileInfo]?)
    case cancelBackgroundLogin

    // Preset import
    case importPresets
    case dismissImportResult

    // Export
    case startExport
    case exportAccounts(includePasswords: Bool)
    case cancelExport
    case dismissExportResult
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

            // MARK: - Selection

            case .selectAccount(let id):
                state.selectedAccountId = id
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
                state.editProfilePins = [:]
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
                state.editProfilePins = account.profilePins
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
                        isPinned: state.editIsPinned, profilePins: state.editProfilePins
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

            case .setEditProfilePin(let profileNo, let pin):
                state.editProfilePins[profileNo] = String(pin.filter { $0.isASCII && $0.isNumber }.prefix(4))
                return .none

            // MARK: - Login

            case .startLogin(let account):
                guard !state.isLoggingIn else { return .none }
                state.isLoggingIn = true
                state.windowLoginFallbackId = nil
                state.loginStatus = String(localized: "Logging in...")
                state.selectedAccountId = account.id

                var loginTarget = account
                loginTarget.password = useCase.loadPassword(forAccountId: account.id) ?? account.password
                state.loginAccount = loginTarget
                state.showLoginWebView = true
                return .none

            case .loginCompleted(let success, let message):
                // 창 로그인 결과가 진행 중인 메뉴바 로그인의 잠금을 풀면 안 된다
                if state.backgroundLoginRunId == nil { state.isLoggingIn = false }
                state.loginStatus = message
                if success, let id = state.loginAccount?.id {
                    useCase.markUsed(in: &state.accounts, id: id)
                }
                return .none

            case .cancelLogin:
                if state.backgroundLoginRunId == nil {
                    state.isLoggingIn = false
                    state.loginStatus = String(localized: "Login cancelled.")
                }
                state.showLoginWebView = false
                state.loginAccount = nil
                return .none

            case .dismissLoginWebView:
                state.showLoginWebView = false
                state.loginAccount = nil
                return .none

            case .setOtpCode(let value):
                // 붙여넣기한 "123 456" 같은 값도 받되 숫자 6자리만 남긴다
                state.otpCode = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                return .none

            case .profilesCollected(let accountId, let profiles):
                useCase.mergeProfiles(in: &state.accounts, id: accountId, collected: profiles)
                return .none

            // MARK: - Menu Bar

            case .startBackgroundLogin(let account):
                guard !state.isLoggingIn else { return .none }
                let runId = UUID()
                state.isLoggingIn = true
                state.backgroundLoginRunId = runId
                state.backgroundLoginAccountId = account.id
                state.windowLoginFallbackId = nil
                state.loginStatus = String(localized: "Logging in...")

                var target = account
                target.password = useCase.loadPassword(forAccountId: account.id) ?? account.password
                let loginTarget = target
                let otp = state.otpCode
                let url = SettingsState.loginURL(for: account.accountType)
                return .run {
                    let result = await BackgroundLogin.run(runId: runId, account: loginTarget, otp: otp, url: url)
                    return .backgroundLoginFinished(
                        runId: runId, accountId: loginTarget.id, outcome: result.outcome,
                        message: result.message, profiles: result.profiles
                    )
                }

            case .backgroundLoginFinished(let runId, let id, let outcome, let message, let profiles):
                if let profiles {
                    useCase.mergeProfiles(in: &state.accounts, id: id, collected: profiles)
                }
                // 취소됐거나 다른 실행으로 대체된 실행의 결과는 화면 상태에 반영하지 않는다
                guard runId == state.backgroundLoginRunId else { return .none }
                state.isLoggingIn = false
                state.backgroundLoginRunId = nil
                state.backgroundLoginAccountId = nil
                state.loginStatus = message
                switch outcome {
                case .submitted, .profileSelected, .profileSkipped:
                    useCase.markUsed(in: &state.accounts, id: id)
                    state.otpCode = ""   // 페어링 코드는 한 번 쓰면 끝난다
                case .credentialsFilled, .profilePending, .profileNotFound, .failed:
                    // 창 없이는 사람이 프로필을 고를 수 없다 — 창에서 다시 하도록 제안
                    state.windowLoginFallbackId = id
                }
                return .none

            case .cancelBackgroundLogin:
                guard let runId = state.backgroundLoginRunId else { return .none }
                // 사용자가 취소한 것이므로 창 로그인 제안 없이 바로 정리한다. 늦게 오는 결과는 runId로 걸러진다.
                state.isLoggingIn = false
                state.backgroundLoginRunId = nil
                state.backgroundLoginAccountId = nil
                state.loginStatus = String(localized: "Login cancelled.")
                return .run {
                    await BackgroundLogin.cancel(runId: runId)
                    return nil
                }

            // MARK: - Preset Import

            case .importPresets:
                let result = useCase.importPresetAccounts(into: &state.accounts)
                state.importResult = result
                return .none

            case .dismissImportResult:
                state.importResult = nil
                return .none

            case .startExport:
                state.isConfirmingExport = true
                return .none

            case .exportAccounts(let includePasswords):
                state.isConfirmingExport = false
                state.exportResult = useCase.exportAccounts(
                    state.accounts,
                    includePasswords: includePasswords
                )
                return .none

            case .cancelExport:
                state.isConfirmingExport = false
                return .none

            case .dismissExportResult:
                state.exportResult = nil
                return .none
            }
        }
    }
}
