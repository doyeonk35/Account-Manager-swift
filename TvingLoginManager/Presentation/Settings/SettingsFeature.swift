import Foundation

typealias SettingsStore = Store<SettingsState, SettingsAction>

struct SettingsState {
    var qcLoginURL: String
    var qaLoginURL: String

    static let defaultQcURL = "https://user.tving.com/"
    static let defaultQaURL = "https://userqa.tving.com/tv/login/qrcode.tving"

    init(
        qcLoginURL: String = UserDefaults.standard.string(forKey: "loginURL_QC") ?? defaultQcURL,
        qaLoginURL: String = UserDefaults.standard.string(forKey: "loginURL_QA") ?? defaultQaURL
    ) {
        self.qcLoginURL = qcLoginURL
        self.qaLoginURL = qaLoginURL
    }

    static func loginURL(for accountType: AccountType) -> URL {
        switch accountType {
        case .qc:
            let urlString = UserDefaults.standard.string(forKey: "loginURL_QC") ?? defaultQcURL
            return URL(string: urlString) ?? URL(string: defaultQcURL)!
        case .qa:
            let urlString = UserDefaults.standard.string(forKey: "loginURL_QA") ?? defaultQaURL
            return URL(string: urlString) ?? URL(string: defaultQaURL)!
        }
    }
}

enum SettingsAction: Sendable {
    case setQcLoginURL(String)
    case setQaLoginURL(String)
    case resetToDefaults
}

enum SettingsEnvironment {
    static let reducer: @MainActor (inout SettingsState, SettingsAction) -> Effect<SettingsAction> = { state, action in
        switch action {
        case .setQcLoginURL(let url):
            state.qcLoginURL = url
            UserDefaults.standard.set(url, forKey: "loginURL_QC")
            return .none

        case .setQaLoginURL(let url):
            state.qaLoginURL = url
            UserDefaults.standard.set(url, forKey: "loginURL_QA")
            return .none

        case .resetToDefaults:
            state.qcLoginURL = SettingsState.defaultQcURL
            state.qaLoginURL = SettingsState.defaultQaURL
            UserDefaults.standard.set(SettingsState.defaultQcURL, forKey: "loginURL_QC")
            UserDefaults.standard.set(SettingsState.defaultQaURL, forKey: "loginURL_QA")
            return .none
        }
    }
}
