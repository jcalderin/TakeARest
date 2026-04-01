import SwiftUI

/// The main entry point for Respite.
///
/// Wires together AppSettings → TimerManager → OverlayService,
/// and connects the menubar panel + preferences window.
@main
struct RespiteApp: App {
    /// Persisted app settings (timers array).
    @State private var settings: AppSettings

    /// Manages all timer engines and break queueing.
    @State private var timerManager: TimerManager

    /// Manages the full-screen break overlay windows.
    @State private var overlayService: OverlayService

    var body: some Scene {
        MenuBarExtra("Respite", systemImage: "cup.and.saucer.fill") {
            MenuBarView(timerManager: timerManager, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView(settings: settings, timerManager: timerManager)
        }
    }

    init() {
        let settings = AppSettings()
        let manager = TimerManager(settings: settings)
        let overlay = OverlayService(timerManager: manager)

        _settings = State(initialValue: settings)
        _timerManager = State(initialValue: manager)
        _overlayService = State(initialValue: overlay)

        // Wire manager → overlay
        manager.onBreakStarted = { [overlay] timer, engine in
            overlay.show(for: timer, engine: engine)
        }
        manager.onBreakEnded = { [overlay] in
            overlay.dismiss()
        }

        // Start all engines based on current timers + schedules
        manager.syncEngines()
    }
}
