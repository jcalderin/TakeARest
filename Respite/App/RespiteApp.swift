import SwiftUI

@main
struct RespiteApp: App {
    /// Shared settings instance — the single source of truth.
    @State private var settings: AppSettings

    /// The core timer engine — drives break scheduling.
    @State private var timerService: TimerService

    var body: some Scene {
        MenuBarExtra("Respite", systemImage: "cup.and.saucer.fill") {
            MenuBarView(timerService: timerService)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView(settings: settings)
        }
    }

    init() {
        let settings = AppSettings()
        let timer = TimerService(settings: settings)
        _settings = State(initialValue: settings)
        _timerService = State(initialValue: timer)

        // Auto-start the timer on launch
        timer.start()
    }
}
