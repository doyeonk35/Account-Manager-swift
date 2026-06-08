import SwiftUI

@main
struct TvingLoginManagerApp: App {
    @StateObject private var accountManager = AccountManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountManager)
                .frame(minWidth: 700, minHeight: 500)
        }
        .defaultSize(width: 800, height: 600)
    }
}
