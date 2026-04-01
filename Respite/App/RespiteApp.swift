import SwiftUI

@main
struct RespiteApp: App {
    var body: some Scene {
        MenuBarExtra("Respite", systemImage: "cup.and.saucer.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            PreferencesView()
        }
    }
}
