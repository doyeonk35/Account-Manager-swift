import Foundation

typealias SettingsStore = Store<SettingsState, SettingsAction>

struct SettingsState {
    /// QC·QA 개발 서버 URL. 사용자가 바꾸지 않았으면 앱 기본값(Info.plist)과 같다.
    var qcLoginURL: String
    var qaLoginURL: String
    /// QC 계정을 운영 서버로 로그인한다. 개발 URL은 그대로 보존된다.
    var qcUsesProduction: Bool

    var draftQcLoginURL: String
    var draftQaLoginURL: String

    static let defaultQcURL = Bundle.main.object(forInfoDictionaryKey: "DefaultQCLoginURL") as? String ?? ""
    static let defaultQaURL = Bundle.main.object(forInfoDictionaryKey: "DefaultQALoginURL") as? String ?? ""
    static let prodURL = "https://user.tving.com/tv/login/qrcode.tving"

    static let qcURLKey = "loginURL_QC"
    static let qaURLKey = "loginURL_QA"
    static let qcTargetKey = "qcTarget"   // "production" 이면 운영, 없으면 개발

    var isUsingProdURL: Bool { qcUsesProduction }

    var hasUnsavedChanges: Bool {
        draftQcLoginURL != qcLoginURL || draftQaLoginURL != qaLoginURL
    }

    var canSave: Bool {
        hasUnsavedChanges && Self.isValidLoginURL(draftQcLoginURL) && Self.isValidLoginURL(draftQaLoginURL)
    }

    /// https 이고 호스트가 있어야 한다. 잘못된 URL은 로그인 창이 "Preparing..."에서 멈추는 원인이 된다.
    static func isValidLoginURL(_ string: String) -> Bool {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespaces)),
              url.scheme?.lowercased() == "https",
              let host = url.host(), !host.isEmpty
        else { return false }
        return true
    }

    init(
        qcLoginURL: String = UserDefaults.standard.string(forKey: qcURLKey) ?? defaultQcURL,
        qaLoginURL: String = UserDefaults.standard.string(forKey: qaURLKey) ?? defaultQaURL,
        qcUsesProduction: Bool = UserDefaults.standard.string(forKey: qcTargetKey) == "production"
    ) {
        self.qcLoginURL = qcLoginURL
        self.qaLoginURL = qaLoginURL
        self.qcUsesProduction = qcUsesProduction
        self.draftQcLoginURL = qcLoginURL
        self.draftQaLoginURL = qaLoginURL
    }

    static func loginURL(for accountType: AccountType) -> URL {
        if accountType == .qc, UserDefaults.standard.string(forKey: qcTargetKey) == "production" {
            return URL(string: prodURL)!
        }
        let (key, fallback) = accountType == .qa ? (qaURLKey, defaultQaURL) : (qcURLKey, defaultQcURL)
        // 검증 도입 전에 저장됐거나 직접 써 넣은 잘못된 값은 쓰지 않는다
        let stored = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespaces)
        let urlString = stored.flatMap { isValidLoginURL($0) ? $0 : nil } ?? fallback
        return URL(string: urlString) ?? URL(string: prodURL)!
    }

    /// 기본값과 같은 URL은 저장하지 않는다 — 저장해 두면 업데이트로 기본값이 바뀌어도 옛 값에 묶인다.
    static func persistURL(_ url: String, key: String, default defaultURL: String, in defaults: UserDefaults = .standard) {
        if url == defaultURL {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(url, forKey: key)
        }
    }

    /// 1.6.0 이하가 남긴 값 정리: 기본값을 그대로 복사해 둔 키는 지우고,
    /// "Use Production URL"로 QC URL을 덮어쓴 경우는 QC 대상=운영으로 옮긴다.
    static func migrateStoredURLs(in defaults: UserDefaults = .standard) {
        // "https://user.tving.com/"는 6월 이전 QC 기본값 — 운영 서버라 운영으로 옮긴다
        let storedQC = defaults.string(forKey: qcURLKey)?.trimmingCharacters(in: .whitespaces)
        if storedQC == prodURL || storedQC == "https://user.tving.com/" {
            defaults.set("production", forKey: qcTargetKey)
            defaults.removeObject(forKey: qcURLKey)
        }
        if defaults.string(forKey: qcURLKey) == defaultQcURL { defaults.removeObject(forKey: qcURLKey) }
        if defaults.string(forKey: qaURLKey) == defaultQaURL { defaults.removeObject(forKey: qaURLKey) }
    }
}

enum SettingsAction: Sendable {
    case beginEditing
    case setDraftQcLoginURL(String)
    case setDraftQaLoginURL(String)
    case saveChanges
    case discardChanges
    case resetToDefaults
    case setQcUsesProduction(Bool)
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
            guard state.canSave else { return .none }
            state.draftQcLoginURL = state.draftQcLoginURL.trimmingCharacters(in: .whitespaces)
            state.draftQaLoginURL = state.draftQaLoginURL.trimmingCharacters(in: .whitespaces)
            state.qcLoginURL = state.draftQcLoginURL
            state.qaLoginURL = state.draftQaLoginURL
            SettingsState.persistURL(state.qcLoginURL, key: SettingsState.qcURLKey, default: SettingsState.defaultQcURL)
            SettingsState.persistURL(state.qaLoginURL, key: SettingsState.qaURLKey, default: SettingsState.defaultQaURL)
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
            state.qcUsesProduction = false
            UserDefaults.standard.removeObject(forKey: SettingsState.qcURLKey)
            UserDefaults.standard.removeObject(forKey: SettingsState.qaURLKey)
            UserDefaults.standard.removeObject(forKey: SettingsState.qcTargetKey)
            return .none

        case .setQcUsesProduction(let enabled):
            state.qcUsesProduction = enabled
            if enabled {
                UserDefaults.standard.set("production", forKey: SettingsState.qcTargetKey)
            } else {
                UserDefaults.standard.removeObject(forKey: SettingsState.qcTargetKey)
            }
            return .none
        }
    }
}
