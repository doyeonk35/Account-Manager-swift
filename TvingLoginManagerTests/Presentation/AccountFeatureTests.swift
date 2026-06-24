import Testing
import Foundation
@testable import TvingLoginManager

@Suite("AccountFeature Reducer")
@MainActor
struct AccountFeatureTests {

    let store: Store<AccountState, AccountAction>
    let repository: MockAccountRepository
    let useCase: AccountUseCase

    init() {
        repository = MockAccountRepository()
        useCase = AccountUseCase(repository: repository)
        store = Store(
            initialState: AccountState(),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )
    }

    // MARK: - Load

    @Test("계정 목록을 로드한다")
    func loadPopulatesAccounts() {
        repository.storedAccounts = [
            AccountInfo(title: "A1", username: "u1"),
            AccountInfo(title: "A2", username: "u2"),
        ]

        store.send(.load)

        #expect(store.state.accounts.count == 2)
        #expect(store.state.accounts[0].title == "A1")
    }

    @Test("빈 저장소에서 로드")
    func loadWithEmptyRepository() {
        store.send(.load)
        #expect(store.state.accounts.isEmpty)
    }

    // MARK: - Start Adding

    @Test("추가 모드 진입 시 기본 편집 상태를 설정한다")
    func startAddingSetsDefaults() {
        store.send(.startAdding)

        #expect(store.state.isEditing == true)
        #expect(store.state.editingAccountId == nil)
        #expect(store.state.editTitle == String(localized: "title(Untitled)"))
        #expect(store.state.editUsername == "")
        #expect(store.state.editPassword == "")
        #expect(store.state.editAccountType == .qc)
        #expect(store.state.editPlanType == .basic)
        #expect(store.state.editMemo == "")
    }

    // MARK: - Start Editing

    @Test("편집 모드 진입 시 계정 정보로 폼을 채운다")
    func startEditingPopulatesForm() {
        let account = AccountInfo(
            title: "Test", username: "user1", password: "pw",
            accountType: .qa, planType: .premium, memo: "some memo"
        )

        store.send(.startEditing(account))

        #expect(store.state.isEditing == true)
        #expect(store.state.editingAccountId == account.id)
        #expect(store.state.editTitle == "Test")
        #expect(store.state.editUsername == "user1")
        #expect(store.state.editPassword == "pw")
        #expect(store.state.editAccountType == .qa)
        #expect(store.state.editPlanType == .premium)
        #expect(store.state.editMemo == "some memo")
    }

    // MARK: - Cancel Editing

    @Test("편집 취소 시 상태를 초기화한다")
    func cancelEditingResets() {
        store.send(.startAdding)
        #expect(store.state.isEditing == true)

        store.send(.cancelEditing)

        #expect(store.state.isEditing == false)
        #expect(store.state.editingAccountId == nil)
    }

    // MARK: - Save Edit (Add)

    @Test("새 계정을 저장한다")
    func saveEditAddsNewAccount() {
        store.send(.startAdding)
        store.send(.setEditTitle("New Account"))
        store.send(.setEditUsername("user1"))
        store.send(.setEditPassword("pass1"))
        store.send(.setEditAccountType(.qa))
        store.send(.setEditPlanType(.standard))
        store.send(.setEditMemo("my memo"))

        store.send(.saveEdit)

        #expect(store.state.accounts.count == 1)
        #expect(store.state.accounts[0].title == "New Account")
        #expect(store.state.accounts[0].username == "user1")
        #expect(store.state.accounts[0].accountType == .qa)
        #expect(store.state.accounts[0].planType == .standard)
        #expect(store.state.accounts[0].memo == "my memo")
        #expect(store.state.isEditing == false)
    }

    // MARK: - Save Edit (Update)

    @Test("기존 계정을 수정한다")
    func saveEditUpdatesExisting() {
        let account = AccountInfo(title: "Old", username: "old_u", accountType: .qc)
        let store = Store(
            initialState: AccountState(accounts: [account]),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )

        store.send(.startEditing(account))
        store.send(.setEditTitle("Updated"))
        store.send(.setEditUsername("new_u"))
        store.send(.setEditPassword("new_pw"))
        store.send(.setEditAccountType(.qa))

        store.send(.saveEdit)

        #expect(store.state.accounts.count == 1)
        #expect(store.state.accounts[0].title == "Updated")
        #expect(store.state.accounts[0].username == "new_u")
        #expect(store.state.accounts[0].accountType == .qa)
        #expect(store.state.isEditing == false)
    }

    // MARK: - Edit Form Fields

    @Test("편집 필드 액션이 상태를 업데이트한다")
    func setEditFieldsUpdateState() {
        store.send(.setEditTitle("Title"))
        #expect(store.state.editTitle == "Title")

        store.send(.setEditUsername("user"))
        #expect(store.state.editUsername == "user")

        store.send(.setEditPassword("pass"))
        #expect(store.state.editPassword == "pass")

        store.send(.setEditAccountType(.qa))
        #expect(store.state.editAccountType == .qa)

        store.send(.setEditPlanType(.premium))
        #expect(store.state.editPlanType == .premium)

        store.send(.setEditMemo("memo"))
        #expect(store.state.editMemo == "memo")
    }

    @Test("메모가 250자를 초과하면 잘린다")
    func setEditMemoTruncatesAt250() {
        let longText = String(repeating: "A", count: 300)
        store.send(.setEditMemo(longText))
        #expect(store.state.editMemo.count == 250)
    }

    @Test("메모가 정확히 250자면 그대로 유지된다")
    func setEditMemoAllows250() {
        let exactText = String(repeating: "B", count: 250)
        store.send(.setEditMemo(exactText))
        #expect(store.state.editMemo.count == 250)
        #expect(store.state.editMemo == exactText)
    }

    // MARK: - Edit Form Validation

    @Test("유효성 검증: 사용자명과 비밀번호가 필수이다")
    func editFormValidation() {
        #expect(store.state.isEditFormValid == false)

        store.send(.setEditUsername("user"))
        #expect(store.state.isEditFormValid == false)

        store.send(.setEditPassword("pass"))
        #expect(store.state.isEditFormValid == true)
    }

    @Test("유효성 검증: 제목은 필수가 아니다")
    func editFormDoesNotRequireTitle() {
        store.send(.setEditUsername("user"))
        store.send(.setEditPassword("pass"))
        #expect(store.state.isEditFormValid == true)
        #expect(store.state.editTitle == "")
    }

    // MARK: - Delete

    @Test("삭제 확인 다이얼로그를 설정한다")
    func confirmDeleteSetsAccount() {
        let account = AccountInfo(title: "To Delete", username: "u")
        store.send(.confirmDelete(account))
        #expect(store.state.accountToDelete?.id == account.id)
    }

    @Test("삭제 취소 시 확인 상태를 초기화한다")
    func cancelDeleteClears() {
        let account = AccountInfo(title: "A", username: "u")
        store.send(.confirmDelete(account))
        store.send(.cancelDelete)
        #expect(store.state.accountToDelete == nil)
    }

    @Test("삭제 시 계정과 확인 상태를 모두 제거한다")
    func deleteRemovesAccountAndConfirmation() {
        let account = AccountInfo(title: "A", username: "u")
        let store = Store(
            initialState: AccountState(accounts: [account], accountToDelete: account),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )

        store.send(.delete(account.id))

        #expect(store.state.accounts.isEmpty)
        #expect(store.state.accountToDelete == nil)
    }

    @Test("삭제된 계정이 선택 상태이면 선택을 해제한다")
    func deleteClearsSelectedIfMatches() {
        let account = AccountInfo(title: "A", username: "u")
        let store = Store(
            initialState: AccountState(accounts: [account], selectedAccountId: account.id),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )

        store.send(.delete(account.id))
        #expect(store.state.selectedAccountId == nil)
    }

    @Test("다른 계정이 선택된 상태에서 삭제해도 선택이 유지된다")
    func deleteDoesNotClearUnrelatedSelection() {
        let a1 = AccountInfo(title: "A1", username: "u1")
        let a2 = AccountInfo(title: "A2", username: "u2")
        let store = Store(
            initialState: AccountState(accounts: [a1, a2], selectedAccountId: a2.id),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )

        store.send(.delete(a1.id))

        #expect(store.state.selectedAccountId == a2.id)
        #expect(store.state.accounts.count == 1)
    }

    // MARK: - Login

    @Test("로그인 시작 시 로그인 상태를 설정한다")
    func startLoginSetsState() {
        let account = AccountInfo(title: "Login Test", username: "u", password: "pw")
        repository.storedPasswords[account.id] = "keychain_pw"

        store.send(.startLogin(account))

        #expect(store.state.isLoggingIn == true)
        #expect(store.state.showLoginWebView == true)
        #expect(store.state.selectedAccountId == account.id)
        #expect(store.state.loginAccount != nil)
        #expect(store.state.loginAccount?.password == "keychain_pw")
    }

    @Test("이미 로그인 중이면 두 번째 로그인을 무시한다")
    func startLoginIgnoredWhileLoggingIn() {
        let a1 = AccountInfo(title: "A1", username: "u1")
        let a2 = AccountInfo(title: "A2", username: "u2")

        store.send(.startLogin(a1))
        store.send(.startLogin(a2))

        #expect(store.state.selectedAccountId == a1.id)
    }

    @Test("로그인 성공 시 사용일시를 기록한다")
    func loginCompletedSuccessMarksUsed() {
        let account = AccountInfo(title: "A", username: "u")
        let store = Store(
            initialState: AccountState(accounts: [account], isLoggingIn: true, loginAccount: account),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )

        store.send(.loginCompleted(success: true, message: "Done!"))

        #expect(store.state.isLoggingIn == false)
        #expect(store.state.loginStatus == "Done!")
        #expect(store.state.accounts[0].lastUsed != nil)
    }

    @Test("로그인 실패 시 사용일시를 기록하지 않는다")
    func loginCompletedFailureDoesNotMark() {
        let oldDate = Date.distantPast
        let account = AccountInfo(title: "A", username: "u", lastUsed: oldDate)
        let store = Store(
            initialState: AccountState(accounts: [account], isLoggingIn: true, loginAccount: account),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )

        store.send(.loginCompleted(success: false, message: "Failed"))

        #expect(store.state.isLoggingIn == false)
        #expect(store.state.loginStatus == "Failed")
        #expect(store.state.accounts[0].lastUsed == oldDate)
    }

    @Test("로그인 취소 시 상태를 초기화한다")
    func cancelLoginResets() {
        let store = Store(
            initialState: AccountState(
                isLoggingIn: true, showLoginWebView: true,
                loginAccount: AccountInfo(title: "A", username: "u")
            ),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )

        store.send(.cancelLogin)

        #expect(store.state.isLoggingIn == false)
        #expect(store.state.showLoginWebView == false)
        #expect(store.state.loginAccount == nil)
        #expect(store.state.loginStatus == String(localized: "Login cancelled."))
    }

    @Test("WebView 닫기 시 WebView 상태만 초기화한다")
    func dismissLoginWebView() {
        let store = Store(
            initialState: AccountState(
                showLoginWebView: true,
                loginAccount: AccountInfo(title: "A", username: "u")
            ),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )

        store.send(.dismissLoginWebView)

        #expect(store.state.showLoginWebView == false)
        #expect(store.state.loginAccount == nil)
    }

    // MARK: - OTP

    @Test("OTP 코드를 업데이트한다")
    func setOtpCode() {
        store.send(.setOtpCode("123456"))
        #expect(store.state.otpCode == "123456")
    }

    // MARK: - Preset Import

    private func writePresetsFile(_ presets: [PresetAccount]) throws {
        let dir = PresetAccount.presetsDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(presets)
        try data.write(to: PresetAccount.presetsFileURL)
    }

    private func removePresetsFile() {
        try? FileManager.default.removeItem(at: PresetAccount.presetsFileURL)
    }

    @Test("프리셋 불러오기 후 결과 상태를 설정한다")
    func importPresetsShowsResult() throws {
        let presets = [
            PresetAccount(title: "Test", username: "t@test.com", password: "pw", accountType: .qc),
        ]
        try writePresetsFile(presets)
        defer { removePresetsFile() }

        store.send(.importPresets)

        guard case .success(let imported, _) = store.state.importResult else {
            Issue.record("Expected .success")
            return
        }
        #expect(imported == 1)
        #expect(store.state.accounts.count == 1)
    }

    @Test("프리셋 파일 없을 때 fileNotFound 결과를 설정한다")
    func importPresetsFileNotFound() {
        removePresetsFile()

        store.send(.importPresets)

        guard case .fileNotFound = store.state.importResult else {
            Issue.record("Expected .fileNotFound")
            return
        }
    }

    @Test("프리셋 결과 닫기를 처리한다")
    func dismissImportResult() {
        removePresetsFile()
        store.send(.importPresets)
        #expect(store.state.importResult != nil)

        store.send(.dismissImportResult)
        #expect(store.state.importResult == nil)
    }
}
