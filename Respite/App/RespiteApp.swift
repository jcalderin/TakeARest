import SwiftUI

@main
struct RespiteApp: App {
    /// Shared settings instance — the single source of truth.
    @State private var settings: AppSettings

    /// The core timer engine — drives break scheduling.
    @State private var timerService: TimerService

    /// Manages the full-screen break overlay window.
    @State private var overlayService: OverlayService

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
        let overlay = OverlayService(settings: settings, timerService: timer)

        _settings = State(initialValue: settings)
        _timerService = State(initialValue: timer)
        _overlayService = State(initialValue: overlay)

        // Wire timer → overlay
        timer.onBreakStarted = { [overlay] in
            overlay.show()
        }
        timer.onBreakEnded = { [overlay] in
            overlay.dismiss()
        }

        // Auto-start the timer on launch
        timer.start()
    }
}
