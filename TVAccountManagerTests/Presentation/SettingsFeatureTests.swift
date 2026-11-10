import Testing
import Foundation
@testable import TVAccountManager

@Suite("SettingsFeature Reducer", .serialized)   // UserDefaults.standard 공유
@MainActor
struct SettingsFeatureTests {

    let store: SettingsStore

    init() {
        UserDefaults.standard.removeObject(forKey: "loginURL_QC")
        UserDefaults.standard.removeObject(forKey: "loginURL_QA")
        UserDefaults.standard.removeObject(forKey: SettingsState.qcTargetKey)
        store = SettingsStore(
            initialState: SettingsState(
                qcLoginURL: SettingsState.defaultQcURL,
                qaLoginURL: SettingsState.defaultQaURL
            ),
            reducer: SettingsEnvironment.reducer
        )
    }

    // MARK: - Draft editing

    @Test("드래프트 QC URL을 변경한다")
    func setDraftQcURL() {
        store.send(.setDraftQcLoginURL("https://custom-qc.tving.com/"))

        #expect(store.state.draftQcLoginURL == "https://custom-qc.tving.com/")
        #expect(store.state.qcLoginURL == SettingsState.defaultQcURL)
        #expect(store.state.hasUnsavedChanges == true)
    }

    @Test("드래프트 QA URL을 변경한다")
    func setDraftQaURL() {
        store.send(.setDraftQaLoginURL("https://custom-qa.tving.com/"))

        #expect(store.state.draftQaLoginURL == "https://custom-qa.tving.com/")
        #expect(store.state.qaLoginURL == SettingsState.defaultQaURL)
        #expect(store.state.hasUnsavedChanges == true)
    }

    @Test("변경 없으면 hasUnsavedChanges가 false이다")
    func noChangesNoUnsaved() {
        #expect(store.state.hasUnsavedChanges == false)
    }

    // MARK: - Save

    @Test("변경사항을 저장한다")
    func saveChanges() {
        store.send(.setDraftQcLoginURL("https://new-qc.com/"))
        store.send(.setDraftQaLoginURL("https://new-qa.com/"))

        store.send(.saveChanges)

        #expect(store.state.qcLoginURL == "https://new-qc.com/")
        #expect(store.state.qaLoginURL == "https://new-qa.com/")
        #expect(store.state.hasUnsavedChanges == false)
        #expect(UserDefaults.standard.string(forKey: "loginURL_QC") == "https://new-qc.com/")
        #expect(UserDefaults.standard.string(forKey: "loginURL_QA") == "https://new-qa.com/")
    }

    // MARK: - Discard

    @Test("변경사항을 폐기한다")
    func discardChanges() {
        store.send(.setDraftQcLoginURL("https://changed.com/"))

        store.send(.discardChanges)

        #expect(store.state.draftQcLoginURL == SettingsState.defaultQcURL)
        #expect(store.state.hasUnsavedChanges == false)
    }

    // MARK: - Begin editing

    @Test("편집 시작 시 드래프트를 커밋 값으로 초기화한다")
    func beginEditing() {
        store.send(.setDraftQcLoginURL("https://temp.com/"))
        store.send(.saveChanges)
        store.send(.setDraftQcLoginURL("https://unsaved.com/"))

        store.send(.beginEditing)

        #expect(store.state.draftQcLoginURL == "https://temp.com/")
        #expect(store.state.hasUnsavedChanges == false)
    }

    // MARK: - Reset

    @Test("기본값으로 초기화하면 커밋과 드래프트 모두 리셋된다")
    func resetToDefaults() {
        store.send(.setDraftQcLoginURL("https://changed-qc.com/"))
        store.send(.saveChanges)

        store.send(.resetToDefaults)

        #expect(store.state.qcLoginURL == SettingsState.defaultQcURL)
        #expect(store.state.qaLoginURL == SettingsState.defaultQaURL)
        #expect(store.state.draftQcLoginURL == SettingsState.defaultQcURL)
        #expect(store.state.draftQaLoginURL == SettingsState.defaultQaURL)
        #expect(store.state.hasUnsavedChanges == false)
        // 기본값은 저장하지 않는다 — 다음 업데이트의 기본값을 따라가야 한다
        #expect(UserDefaults.standard.string(forKey: "loginURL_QC") == nil)
        #expect(UserDefaults.standard.string(forKey: "loginURL_QA") == nil)
    }

    @Test("기본값과 같은 URL로 저장하면 저장된 값을 지운다")
    func savingDefaultRemovesOverride() {
        store.send(.setDraftQcLoginURL("https://custom-qc.tving.com/"))
        store.send(.saveChanges)
        #expect(UserDefaults.standard.string(forKey: "loginURL_QC") == "https://custom-qc.tving.com/")

        store.send(.setDraftQcLoginURL(SettingsState.defaultQcURL))
        store.send(.saveChanges)

        #expect(UserDefaults.standard.string(forKey: "loginURL_QC") == nil)
        #expect(SettingsState.loginURL(for: .qc).absoluteString == SettingsState.defaultQcURL)
    }

    // MARK: - QC target

    @Test("QC 대상을 운영으로 바꾸면 운영 URL로 로그인하고, 개발 URL은 보존된다")
    func qcTargetProduction() {
        store.send(.setDraftQcLoginURL("https://custom-qc.tving.com/"))
        store.send(.saveChanges)

        store.send(.setQcUsesProduction(true))
        #expect(store.state.isUsingProdURL)
        #expect(SettingsState.loginURL(for: .qc).absoluteString == SettingsState.prodURL)
        #expect(SettingsState.loginURL(for: .qa).absoluteString == SettingsState.defaultQaURL)

        store.send(.setQcUsesProduction(false))
        #expect(SettingsState.loginURL(for: .qc).absoluteString == "https://custom-qc.tving.com/")
    }

    @Test("기본값으로 초기화하면 QC 대상도 개발로 돌아간다")
    func resetClearsProduction() {
        store.send(.setQcUsesProduction(true))
        store.send(.resetToDefaults)
        #expect(!store.state.qcUsesProduction)
        #expect(UserDefaults.standard.string(forKey: SettingsState.qcTargetKey) == nil)
    }

    // MARK: - Migration

    @Test("이전 버전이 남긴 값 정리: 기본값 복사본은 지우고, 운영 URL은 QC 대상=운영으로 옮긴다")
    func migratesLegacyValues() throws {
        let suite = "SettingsMigrationTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(SettingsState.prodURL, forKey: SettingsState.qcURLKey)
        defaults.set(SettingsState.defaultQaURL, forKey: SettingsState.qaURLKey)
        SettingsState.migrateStoredURLs(in: defaults)
        #expect(defaults.string(forKey: SettingsState.qcTargetKey) == "production")
        #expect(defaults.string(forKey: SettingsState.qcURLKey) == nil)
        #expect(defaults.string(forKey: SettingsState.qaURLKey) == nil)

        // 6월 이전 QC 기본값(운영 호스트)도 운영으로 옮긴다
        defaults.removeObject(forKey: SettingsState.qcTargetKey)
        defaults.set("https://user.tving.com/", forKey: SettingsState.qcURLKey)
        SettingsState.migrateStoredURLs(in: defaults)
        #expect(defaults.string(forKey: SettingsState.qcTargetKey) == "production")
        #expect(defaults.string(forKey: SettingsState.qcURLKey) == nil)

        // 사용자가 직접 바꾼 값은 남긴다
        defaults.set("https://custom-qa.tving.com/", forKey: SettingsState.qaURLKey)
        SettingsState.migrateStoredURLs(in: defaults)
        #expect(defaults.string(forKey: SettingsState.qaURLKey) == "https://custom-qa.tving.com/")
    }

    // MARK: - Default values

    @Test("기본 URL이 Info.plist에서 주입된다")
    func defaultStateValues() {
        // QC/QA URL 값은 setup-plist.sh가 환경별로 주입하고 Info.plist는 gitignore 대상이라,
        // 문자열을 박아두면 환경이 바뀔 때마다 깨진다. 주입이 됐는지(형태)만 검증한다.
        for url in [SettingsState.defaultQcURL, SettingsState.defaultQaURL] {
            #expect(url.hasPrefix("https://"))
            #expect(url.hasSuffix("/tv/login/qrcode.tving"))
        }
        // 운영 URL은 소스에 박힌 상수이므로 값 자체를 검증한다.
        #expect(SettingsState.prodURL == "https://user.tving.com/tv/login/qrcode.tving")
    }

    // MARK: - URL validation

    @Test("로그인 URL은 https와 호스트가 있어야 한다", arguments: [
        ("https://user.tving.com/tv/login", true),
        (" https://qc.tving.com/ ", true),
        ("http://user.tving.com/", false),
        ("user.tving.com", false),
        ("https://", false),
        ("", false),
    ])
    func validatesLoginURL(url: String, valid: Bool) {
        #expect(SettingsState.isValidLoginURL(url) == valid)
    }

    @Test("잘못된 URL은 저장되지 않는다")
    func invalidURLIsNotSaved() {
        store.send(.setDraftQcLoginURL("not a url"))
        #expect(!store.state.canSave)
        store.send(.saveChanges)
        #expect(store.state.qcLoginURL == SettingsState.defaultQcURL)
    }

    @Test("저장된 URL이 검증을 통과하지 못하면 기본 URL로 로그인한다")
    func invalidStoredURLFallsBack() {
        UserDefaults.standard.set("user.tving.com/tv/login", forKey: "loginURL_QA")
        defer { UserDefaults.standard.removeObject(forKey: "loginURL_QA") }
        #expect(SettingsState.loginURL(for: .qa).absoluteString == SettingsState.defaultQaURL)
    }
}
