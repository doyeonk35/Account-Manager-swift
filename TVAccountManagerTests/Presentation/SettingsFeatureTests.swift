import Testing
import Foundation
@testable import TVAccountManager

@Suite("SettingsFeature Reducer")
@MainActor
struct SettingsFeatureTests {

    let store: SettingsStore

    init() {
        UserDefaults.standard.removeObject(forKey: "loginURL_QC")
        UserDefaults.standard.removeObject(forKey: "loginURL_QA")
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
        #expect(UserDefaults.standard.string(forKey: "loginURL_QC") == SettingsState.defaultQcURL)
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
}
