import Foundation
import SwiftUI
import Testing
@testable import Respite

/// Tests for AppSettings model (post multi-timer refactor).
@Suite("AppSettings")
struct AppSettingsTests {

    private func makeSUT(suiteName: String = UUID().uuidString) -> (AppSettings, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: defaults)
        return (settings, defaults)
    }

    // MARK: - Defaults

    @Test("Fresh settings have empty timers array")
    func defaultValues() {
        let (settings, _) = makeSUT()
        #expect(settings.timers.isEmpty)
    }

    // MARK: - Timer CRUD

    @Test("Add timer persists and reloads")
    func addTimerPersistence() {
        let suite = UUID().uuidString
        let (settings, _) = makeSUT(suiteName: suite)

        settings.addTimer(.screenBreak())
        #expect(settings.timers.count == 1)
        #expect(settings.timers[0].name == "Screen Break")

        // Reload from same suite
        let (reloaded, _) = makeSUT(suiteName: suite)
        #expect(reloaded.timers.count == 1)
        #expect(reloaded.timers[0].name == "Screen Break")
    }

    @Test("Update timer modifies existing entry")
    func updateTimer() {
        let (settings, _) = makeSUT()
        let timer = BreakTimer.screenBreak()
        settings.addTimer(timer)

        var updated = timer
        updated.name = "Eye Rest"
        updated.breakIntervalMinutes = 30
        settings.updateTimer(updated)

        #expect(settings.timers.count == 1)
        #expect(settings.timers[0].name == "Eye Rest")
        #expect(settings.timers[0].breakIntervalMinutes == 30)
    }

    @Test("Remove timer deletes entry")
    func removeTimer() {
        let (settings, _) = makeSUT()
        let timer = BreakTimer.screenBreak()
        settings.addTimer(timer)
        #expect(settings.timers.count == 1)

        settings.removeTimer(id: timer.id)
        #expect(settings.timers.isEmpty)
    }

    @Test("Add timer validates fields")
    func addTimerValidates() {
        let (settings, _) = makeSUT()
        var timer = BreakTimer.screenBreak()
        timer.breakIntervalMinutes = 1  // below minimum
        settings.addTimer(timer)

        #expect(settings.timers[0].breakIntervalMinutes == DesignTokens.minBreakIntervalMinutes)
    }

    @Test("Multiple timers persist correctly")
    func multipleTimers() {
        let suite = UUID().uuidString
        let (settings, _) = makeSUT(suiteName: suite)

        settings.addTimer(.screenBreak())
        settings.addTimer(.standUpAndWalk())
        #expect(settings.timers.count == 2)

        let (reloaded, _) = makeSUT(suiteName: suite)
        #expect(reloaded.timers.count == 2)
        #expect(reloaded.timers[0].name == "Screen Break")
        #expect(reloaded.timers[1].name == "Stand Up & Walk")
    }

    // MARK: - Migration

    @Test("Legacy settings migrate to a BreakTimer")
    func migrationFromLegacy() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!

        // Write old-format keys
        defaults.set(25, forKey: "breakIntervalMinutes")
        defaults.set(30, forKey: "breakDurationSeconds")
        defaults.set(true, forKey: "showCountdown")
        defaults.set(true, forKey: "playSoundOnBreak")
        defaults.set(7.0, forKey: "dimAnimationDuration")
        defaults.set(0.9, forKey: "overlayOpacity")
        defaults.set("#1A1A2E", forKey: "overlayColorHex")
        defaults.set("Rest your eyes", forKey: "breakMessage")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.timers.count == 1)
        let timer = settings.timers[0]
        #expect(timer.name == "Break Timer")
        #expect(timer.breakIntervalMinutes == 25)
        #expect(timer.breakDurationSeconds == 30)
        #expect(timer.showCountdown == true)
        #expect(timer.playSoundOnBreak == true)
        #expect(timer.overlayColorHex == "#1A1A2E")
        #expect(timer.breakMessage == "Rest your eyes")

        // Old keys should be cleaned up
        #expect(defaults.object(forKey: "breakIntervalMinutes") == nil)
    }
}
