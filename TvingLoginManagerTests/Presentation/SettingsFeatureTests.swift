import Testing
import Foundation
@testable import TvingLoginManager

@Suite("SettingsFeature Reducer")
@MainActor
struct SettingsFeatureTests {

    let store: Store<SettingsState, SettingsAction>

    init() {
        UserDefaults.standard.removeObject(forKey: "loginURL_QC")
        UserDefaults.standard.removeObject(forKey: "loginURL_QA")
        store = Store(
            initialState: SettingsState(
                qcLoginURL: SettingsState.defaultQcURL,
                qaLoginURL: SettingsState.defaultQaURL
            ),
            reducer: SettingsEnvironment.reducer
        )
    }

    // MARK: - QC URL

    @Test("QC 로그인 URL을 변경한다")
    func setQcLoginURL() {
        let custom = "https://custom-qc.tving.com/"

        store.send(.setQcLoginURL(custom))

        #expect(store.state.qcLoginURL == custom)
        #expect(UserDefaults.standard.string(forKey: "loginURL_QC") == custom)
    }

    @Test("QC URL을 빈 문자열로 설정 가능하다")
    func setQcLoginURLEmpty() {
        store.send(.setQcLoginURL(""))
        #expect(store.state.qcLoginURL == "")
    }

    // MARK: - QA URL

    @Test("QA 로그인 URL을 변경한다")
    func setQaLoginURL() {
        let custom = "https://custom-qa.tving.com/"

        store.send(.setQaLoginURL(custom))

        #expect(store.state.qaLoginURL == custom)
        #expect(UserDefaults.standard.string(forKey: "loginURL_QA") == custom)
    }

    // MARK: - Reset

    @Test("기본값으로 초기화한다")
    func resetToDefaults() {
        store.send(.setQcLoginURL("https://changed-qc.com/"))
        store.send(.setQaLoginURL("https://changed-qa.com/"))

        store.send(.resetToDefaults)

        #expect(store.state.qcLoginURL == SettingsState.defaultQcURL)
        #expect(store.state.qaLoginURL == SettingsState.defaultQaURL)
        #expect(UserDefaults.standard.string(forKey: "loginURL_QC") == SettingsState.defaultQcURL)
        #expect(UserDefaults.standard.string(forKey: "loginURL_QA") == SettingsState.defaultQaURL)
    }

    @Test("이미 기본값일 때 초기화해도 문제없다")
    func resetWhenAlreadyDefault() {
        store.send(.resetToDefaults)

        #expect(store.state.qcLoginURL == SettingsState.defaultQcURL)
        #expect(store.state.qaLoginURL == SettingsState.defaultQaURL)
    }

    // MARK: - Default values

    @Test("기본 URL 상수값이 올바르다")
    func defaultStateValues() {
        #expect(SettingsState.defaultQcURL == "https://user.tving.com/")
        #expect(SettingsState.defaultQaURL == "https://userqa.tving.com/tv/login/qrcode.tving")
    }
}
