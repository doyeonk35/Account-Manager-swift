import Testing
import Foundation
@testable import TVAccountManager

private func profile(_ no: Int, _ name: String, locked: Bool = false, main: Bool = false,
                     grade: String = "CPTG0019") -> ProfileInfo {
    ProfileInfo(profileNo: no, name: name, isLocked: locked, isMain: main, gradeCode: grade)
}

@Suite("ProfileInfo")
struct ProfileInfoTests {

    @Test("PIN은 숫자 4자리만 허용한다", arguments: [
        ("1234", true), ("0000", true), ("123", false), ("12345", false),
        ("12a4", false), ("", false), ("١٢٣٤", false), ("１２３４", false),
    ])
    func pinValidation(pin: String, valid: Bool) {
        #expect(ProfileInfo.isValidPin(pin) == valid)
    }

    @Test("연령 코드 표시: 제한 없음, 추정 숫자, 모르는 코드는 원본")
    func gradeDisplay() {
        #expect(profile(1, "a", grade: "CPTG0019").gradeDisplayName == String(localized: "No limit"))
        #expect(profile(1, "a", grade: "CPTG0012").gradeDisplayName == "12+")
        #expect(profile(1, "a", grade: "CPTG9999").gradeDisplayName == "CPTG9999")
    }

    @Test("구버전 JSON(profiles 없음)은 빈 목록으로 디코딩한다")
    func decodesLegacyJSON() throws {
        let json = """
        {"id":"\(UUID().uuidString)","title":"T","username":"u","account_type":"QC",
         "last_used":"2026-01-15T10:30:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let account = try decoder.decode(AccountInfo.self, from: Data(json.utf8))
        #expect(account.profiles.isEmpty)
        #expect(account.profilePins.isEmpty)
    }

    @Test("profiles는 JSON에 들어가고 PIN은 들어가지 않는다")
    func encodesProfilesWithoutPins() throws {
        let account = AccountInfo(
            title: "T", username: "u",
            profiles: [profile(42, "tester", locked: true)],
            profilePins: [42: "9876"]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(account)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("tester"))
        #expect(!json.contains("9876"))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AccountInfo.self, from: data)
        #expect(decoded.profiles == account.profiles)
        #expect(decoded.profilePins.isEmpty)
    }
}

@Suite("LoginService 잠금 프로필 선택")
struct LoginServiceLockedPickTests {

    private func candidate(_ name: String, no: Int?, locked: Bool = true, main: Bool = false) -> ProfileCandidate {
        ProfileCandidate(name: name, locked: locked, restricted: false, profileNo: no, main: main, grade: "CPTG0019")
    }

    @Test("PIN이 있는 잠금 프로필 중 대표 프로필을 먼저 고른다")
    func prefersMainWithPin() {
        let rows = [candidate("a", no: 1), candidate("b", no: 2, main: true), candidate("c", no: 3)]
        #expect(LoginService.pickLockedProfile(from: rows, pins: [1: "1111", 2: "2222"]) == 1)
    }

    @Test("대표 프로필에 PIN이 없으면 PIN 있는 첫 프로필")
    func fallsBackToFirstWithPin() {
        let rows = [candidate("a", no: 1, main: true), candidate("b", no: 2), candidate("c", no: 3)]
        #expect(LoginService.pickLockedProfile(from: rows, pins: [3: "3333", 2: "2222"]) == 1)
    }

    @Test("PIN이 없거나 형식이 틀리거나 profileNo를 모르면 nil")
    func nilWithoutUsablePin() {
        let rows = [candidate("a", no: 1), candidate("b", no: nil)]
        #expect(LoginService.pickLockedProfile(from: rows, pins: [:]) == nil)
        #expect(LoginService.pickLockedProfile(from: rows, pins: [1: "12"]) == nil)
    }

    @Test("DOM 폴백(profileNo 없음)이면 수집 목록을 만들지 않는다")
    func collectsOnlyFromPayload() {
        let full = [candidate("a", no: 1, main: true), candidate("b", no: 2, locked: false)]
        let collected = LoginService.collectedProfiles(from: full)
        #expect(collected == [profile(1, "a", locked: true, main: true), profile(2, "b")])

        let partial = [candidate("a", no: 1), ProfileCandidate(name: "b", locked: false, restricted: false)]
        #expect(LoginService.collectedProfiles(from: partial) == nil)
    }
}

@Suite("AccountUseCase 프로필")
@MainActor
struct AccountUseCaseProfileTests {

    let repository = MockAccountRepository()
    var useCase: AccountUseCase { AccountUseCase(repository: repository) }

    private func key(_ id: UUID, _ no: Int) -> String {
        KeychainService.profilePinKey(accountId: id, profileNo: no)
    }

    @Test("병합: 남은 프로필 PIN 유지, 신규 추가, 사라진 프로필 PIN 삭제")
    func mergeKeepsAddsRemoves() {
        var account = AccountInfo(title: "T", username: "u",
                                  profiles: [profile(1, "old", locked: true), profile(2, "gone", locked: true)],
                                  profilePins: [1: "1111", 2: "2222"])
        repository.storedPins = [key(account.id, 1): "1111", key(account.id, 2): "2222"]
        var accounts = [account]

        useCase.mergeProfiles(in: &accounts, id: account.id,
                              collected: [profile(1, "renamed", locked: true), profile(3, "new")])

        account = accounts[0]
        #expect(account.profiles.map(\.profileNo) == [1, 3])
        #expect(account.profiles[0].name == "renamed")
        #expect(account.profilePins == [1: "1111"])
        #expect(repository.storedPins == [key(account.id, 1): "1111"])
        #expect(repository.storedAccounts.first?.profiles.count == 2)
    }

    @Test("빈 수집 결과는 저장 목록을 건드리지 않는다")
    func mergeIgnoresEmpty() {
        let account = AccountInfo(title: "T", username: "u", profiles: [profile(1, "a")])
        var accounts = [account]
        useCase.mergeProfiles(in: &accounts, id: account.id, collected: [])
        #expect(accounts[0].profiles.count == 1)
        #expect(repository.saveAccountsCallCount == 0)
    }

    @Test("로드 시 Keychain에서 PIN을 채운다")
    func loadFillsPins() {
        let account = AccountInfo(title: "T", username: "u", profiles: [profile(7, "a", locked: true)])
        repository.storedAccounts = [account]
        repository.storedPins = [key(account.id, 7): "7777"]
        #expect(useCase.loadAccounts()[0].profilePins == [7: "7777"])
    }

    @Test("편집 저장: 4자리는 저장, 빈 값은 삭제")
    func updateSavesAndDeletesPins() {
        let account = AccountInfo(title: "T", username: "u", password: "pw",
                                  profiles: [profile(1, "a", locked: true), profile(2, "b", locked: true)],
                                  profilePins: [2: "2222"])
        repository.storedPins = [key(account.id, 2): "2222"]
        var accounts = [account]

        useCase.updateAccount(in: &accounts, id: account.id, title: "T", username: "u", password: "pw",
                              accountType: .qc, planType: .none, memo: "", isPinned: false,
                              profilePins: [1: "1234", 2: ""])

        #expect(accounts[0].profilePins == [1: "1234"])
        #expect(repository.storedPins == [key(account.id, 1): "1234"])
    }

    @Test("병합: 잠금이 풀린 프로필의 PIN은 지운다")
    func mergeDropsPinWhenUnlocked() {
        let account = AccountInfo(title: "T", username: "u", profiles: [profile(1, "a", locked: true)],
                                  profilePins: [1: "1111"])
        repository.storedPins = [key(account.id, 1): "1111"]
        var accounts = [account]

        useCase.mergeProfiles(in: &accounts, id: account.id, collected: [profile(1, "a", locked: false)])

        #expect(accounts[0].profilePins.isEmpty)
        #expect(repository.storedPins.isEmpty)
    }

    @Test("편집 저장: 폼에 없던 프로필의 PIN은 건드리지 않는다")
    func updateLeavesAbsentKeysAlone() {
        let account = AccountInfo(title: "T", username: "u", password: "pw",
                                  profiles: [profile(1, "a", locked: true), profile(2, "b", locked: true)],
                                  profilePins: [2: "2222"])
        repository.storedPins = [key(account.id, 2): "2222"]
        var accounts = [account]

        useCase.updateAccount(in: &accounts, id: account.id, title: "T", username: "u", password: "pw",
                              accountType: .qc, planType: .none, memo: "", isPinned: false,
                              profilePins: [1: "1234"])

        #expect(accounts[0].profilePins == [1: "1234", 2: "2222"])
        #expect(repository.storedPins[key(account.id, 2)] == "2222")
    }

    @Test("계정 삭제 시 프로필 목록에 없는 PIN도 삭제한다")
    func deleteRemovesOrphanPins() {
        let account = AccountInfo(title: "T", username: "u", profilePins: [7: "7777"])
        repository.storedPins = [key(account.id, 7): "7777"]
        var accounts = [account]
        useCase.deleteAccount(from: &accounts, id: account.id)
        #expect(repository.storedPins.isEmpty)
    }

    @Test("PIN 판정 시간 초과: 입력칸이 비어 있을 때만 거부로 본다")
    func pinTimeoutVerdict() {
        #expect(LoginService.pinTimeoutVerdict(lastState: "empty"))
        #expect(!LoginService.pinTimeoutVerdict(lastState: "gone"))
        #expect(!LoginService.pinTimeoutVerdict(lastState: "filled"))
        #expect(!LoginService.pinTimeoutVerdict(lastState: ""))
    }

    @Test("계정 삭제 시 프로필 PIN도 삭제한다")
    func deleteRemovesPins() {
        let account = AccountInfo(title: "T", username: "u", profiles: [profile(1, "a", locked: true)])
        repository.storedPins = [key(account.id, 1): "1111"]
        var accounts = [account]
        useCase.deleteAccount(from: &accounts, id: account.id)
        #expect(repository.storedPins.isEmpty)
    }

    @Test("내보내기는 비밀번호 포함일 때만 PIN을 넣는다")
    func exportIncludesPinsOnlyWithPasswords() {
        let account = AccountInfo(title: "T", username: "u", password: "pw",
                                  profiles: [profile(5, "a", locked: true)], profilePins: [5: "5555"])
        let with = PresetAccount(from: account, includePassword: true)
        let without = PresetAccount(from: account, includePassword: false)
        #expect(with.profilePins == ["5": "5555"])
        #expect(without.profilePins == nil)
        #expect(without.profiles?.count == 1)
        #expect(with.validProfilePins == [5: "5555"])
    }
}

@Suite("AccountFeature 프로필 PIN 편집")
@MainActor
struct AccountFeatureProfileTests {

    @Test("PIN 입력은 숫자만 4자리까지 받고, 덜 찬 PIN은 저장을 막는다")
    func pinInputFiltered() {
        let repository = MockAccountRepository()
        let store = Store(initialState: AccountState(),
                          reducer: AccountEnvironment.reducer(useCase: AccountUseCase(repository: repository)))
        let account = AccountInfo(title: "T", username: "u", profiles: [profile(1, "a", locked: true)])
        repository.storedAccounts = [account]
        repository.storedPasswords = [account.id: "pw"]
        store.send(.load)
        store.send(.startEditing(store.state.accounts[0]))
        #expect(store.state.editingProfiles.count == 1)

        store.send(.setEditProfilePin(profileNo: 1, pin: "1a2-34567"))
        #expect(store.state.editProfilePins[1] == "1234")
        #expect(store.state.isEditFormValid)

        store.send(.setEditProfilePin(profileNo: 1, pin: "12"))
        #expect(!store.state.isEditFormValid)
    }

    @Test("수집한 프로필을 계정에 반영한다")
    func profilesCollectedMerges() {
        let repository = MockAccountRepository()
        let store = Store(initialState: AccountState(),
                          reducer: AccountEnvironment.reducer(useCase: AccountUseCase(repository: repository)))
        let account = AccountInfo(title: "T", username: "u")
        repository.storedAccounts = [account]
        store.send(.load)
        store.send(.profilesCollected(accountId: account.id, profiles: [profile(1, "a")]))
        #expect(store.state.accounts[0].profiles == [profile(1, "a")])
    }
}
