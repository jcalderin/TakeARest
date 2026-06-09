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

    /// Manages the pre-break heads-up (pill / buttons / bar).
    @State private var preWarnService: PreWarnService

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
        let preWarn = PreWarnService()

        _settings = State(initialValue: settings)
        _timerManager = State(initialValue: manager)
        _overlayService = State(initialValue: overlay)
        _preWarnService = State(initialValue: preWarn)

        // Wire manager → overlay + pre-warning
        manager.onBreakStarted = { [overlay, preWarn] timer, engine in
            preWarn.dismiss() // the heads-up gives way to the actual break
            overlay.show(for: timer, engine: engine)
        }
        manager.onBreakEnded = { [overlay] in
            overlay.dismiss()
        }
        manager.onPreWarn = { [preWarn] timer, engine in
            preWarn.show(
                for: timer,
                engine: engine,
                onStartNow: { engine.takeBreakNow() },
                onSkip: { engine.skipNextBreak() }
            )
        }
        manager.onPreWarnCancel = { [preWarn] in
            preWarn.dismiss()
        }

        // Start all engines based on current timers + schedules
        manager.syncEngines()
    }
}
