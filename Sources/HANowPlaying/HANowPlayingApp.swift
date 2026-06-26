import SwiftUI
import Sparkle

@main
struct HANowPlayingApp: App {
    @State private var store = AppState()
    @State private var updater = UpdateController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(store)
                .environment(updater)
                .task { updater.start() }
        } label: {
            MenuBarLabel()
                .environment(store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
