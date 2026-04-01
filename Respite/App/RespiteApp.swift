import SwiftUI

@main
struct RespiteApp: App {
    /// Shared settings instance — the single source of truth.
    /// Injected into the environment so all views can access it.
    @State private var settings = AppSettings()

    var body: some Scene {
        MenuBarExtra("Respite", systemImage: "cup.and.saucer.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            PreferencesView(settings: settings)
        }
    }
}
