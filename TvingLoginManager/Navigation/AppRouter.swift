import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case accounts = "Accounts"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .accounts: "person.2"
        case .settings: "gearshape"
        }
    }
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case environment = "Environment"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .environment: "link"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var tab: SidebarTab = .accounts
    @Published var settingsCategory: SettingsCategory?

    func navigateTo(tab: SidebarTab) {
        self.tab = tab
        settingsCategory = nil
    }
}
