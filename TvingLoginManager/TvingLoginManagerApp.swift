import SwiftUI

@main
struct TvingLoginManagerApp: App {
    @StateObject private var accountManager = AccountManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountManager)
                .frame(minWidth: 900, minHeight: 500)
        }
        .defaultSize(width: 1100, height: 650)
    }
}
