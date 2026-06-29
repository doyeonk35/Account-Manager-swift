import Foundation

typealias SettingsStore = Store<SettingsState, SettingsAction>

struct SettingsState {
    var qcLoginURL: String
    var qaLoginURL: String

    var draftQcLoginURL: String
    var draftQaLoginURL: String

    static let defaultQcURL = Bundle.main.object(forInfoDictionaryKey: "DefaultQCLoginURL") as? String ?? ""
    static let defaultQaURL = Bundle.main.object(forInfoDictionaryKey: "DefaultQALoginURL") as? String ?? ""
    static let prodURL = "https://user.tving.com/tv/login/qrcode.tving"

    var isUsingProdURL: Bool {
        qcLoginURL == Self.prodURL
    }

    var hasUnsavedChanges: Bool {
        draftQcLoginURL != qcLoginURL || draftQaLoginURL != qaLoginURL
    }

    init(
        qcLoginURL: String = UserDefaults.standard.string(forKey: "loginURL_QC") ?? defaultQcURL,
        qaLoginURL: String = UserDefaults.standard.string(forKey: "loginURL_QA") ?? defaultQaURL
    ) {
        self.qcLoginURL = qcLoginURL
        self.qaLoginURL = qaLoginURL
        self.draftQcLoginURL = qcLoginURL
        self.draftQaLoginURL = qaLoginURL
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
    case beginEditing
    case setDraftQcLoginURL(String)
    case setDraftQaLoginURL(String)
    case saveChanges
    case discardChanges
    case resetToDefaults
    case useProductionURL
}

enum SettingsEnvironment {
    static let reducer: @MainActor (inout SettingsState, SettingsAction) -> Effect<SettingsAction> = { state, action in
        switch action {
        case .beginEditing:
            state.draftQcLoginURL = state.qcLoginURL
            state.draftQaLoginURL = state.qaLoginURL
            return .none

        case .setDraftQcLoginURL(let url):
            state.draftQcLoginURL = url
            return .none

        case .setDraftQaLoginURL(let url):
            state.draftQaLoginURL = url
            return .none

        case .saveChanges:
            state.qcLoginURL = state.draftQcLoginURL
            state.qaLoginURL = state.draftQaLoginURL
            UserDefaults.standard.set(state.qcLoginURL, forKey: "loginURL_QC")
            UserDefaults.standard.set(state.qaLoginURL, forKey: "loginURL_QA")
            return .none

        case .discardChanges:
            state.draftQcLoginURL = state.qcLoginURL
            state.draftQaLoginURL = state.qaLoginURL
            return .none

        case .resetToDefaults:
            state.qcLoginURL = SettingsState.defaultQcURL
            state.qaLoginURL = SettingsState.defaultQaURL
            state.draftQcLoginURL = SettingsState.defaultQcURL
            state.draftQaLoginURL = SettingsState.defaultQaURL
            UserDefaults.standard.set(SettingsState.defaultQcURL, forKey: "loginURL_QC")
            UserDefaults.standard.set(SettingsState.defaultQaURL, forKey: "loginURL_QA")
            return .none

        case .useProductionURL:
            state.qcLoginURL = SettingsState.prodURL
            state.draftQcLoginURL = SettingsState.prodURL
            UserDefaults.standard.set(SettingsState.prodURL, forKey: "loginURL_QC")
            return .none
        }
    }
}
