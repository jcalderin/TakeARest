import Foundation
import Testing
@testable import Respite

/// Tests for AppSettings model.
///
/// Uses a dedicated UserDefaults suite per test to avoid state leakage
/// between tests and from the running app's actual preferences.
@Suite("AppSettings")
struct AppSettingsTests {

    /// Creates a fresh UserDefaults suite and matching AppSettings instance.
    /// The suite is unique per call to avoid cross-test contamination.
    private func makeSUT(suiteName: String = UUID().uuidString) -> (AppSettings, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: defaults)
        return (settings, defaults)
    }

    // MARK: - Defaults

    @Test("Fresh settings have correct default values")
    func defaultValues() {
        let (settings, _) = makeSUT()
        #expect(settings.breakIntervalMinutes == DesignTokens.defaultBreakIntervalMinutes)
        #expect(settings.breakDurationSeconds == DesignTokens.defaultBreakDurationSeconds)
        #expect(settings.showCountdown == true)
        #expect(settings.playSoundOnBreak == false)
        #expect(settings.dimAnimationDuration == DesignTokens.overlayDimDuration)
    }

    // MARK: - Persistence

    @Test("Settings persist to UserDefaults and reload correctly")
    func persistenceRoundTrip() {
        let suite = UUID().uuidString
        let (settings, _) = makeSUT(suiteName: suite)

        // Change everything from defaults
        settings.breakIntervalMinutes = 45
        settings.breakDurationSeconds = 120
        settings.showCountdown = false
        settings.playSoundOnBreak = true
        settings.dimAnimationDuration = 8.0

        // Create a new instance pointing at the same suite
        let (reloaded, _) = makeSUT(suiteName: suite)
        #expect(reloaded.breakIntervalMinutes == 45)
        #expect(reloaded.breakDurationSeconds == 120)
        #expect(reloaded.showCountdown == false)
        #expect(reloaded.playSoundOnBreak == true)
        #expect(reloaded.dimAnimationDuration == 8.0)
    }

    // MARK: - Clamping

    @Test("Break interval is clamped to valid range")
    func breakIntervalClamping() {
        let (settings, _) = makeSUT()

        settings.breakIntervalMinutes = 1  // below minimum of 5
        #expect(settings.breakIntervalMinutes == DesignTokens.minBreakIntervalMinutes)

        settings.breakIntervalMinutes = 999  // above maximum of 120
        #expect(settings.breakIntervalMinutes == DesignTokens.maxBreakIntervalMinutes)

        settings.breakIntervalMinutes = 30  // within range
        #expect(settings.breakIntervalMinutes == 30)
    }

    @Test("Break duration is clamped to valid range")
    func breakDurationClamping() {
        let (settings, _) = makeSUT()

        settings.breakDurationSeconds = 1  // below minimum of 10
        #expect(settings.breakDurationSeconds == DesignTokens.minBreakDurationSeconds)

        settings.breakDurationSeconds = 999  // above maximum of 300
        #expect(settings.breakDurationSeconds == DesignTokens.maxBreakDurationSeconds)

        settings.breakDurationSeconds = 60  // within range
        #expect(settings.breakDurationSeconds == 60)
    }

    @Test("Dim animation duration is clamped to valid range")
    func dimDurationClamping() {
        let (settings, _) = makeSUT()

        settings.dimAnimationDuration = 0.1  // below minimum of 1.0
        #expect(settings.dimAnimationDuration == 1.0)

        settings.dimAnimationDuration = 99.0  // above maximum of 15.0
        #expect(settings.dimAnimationDuration == DesignTokens.overlayDimDurationMax)

        settings.dimAnimationDuration = 7.5  // within range
        #expect(settings.dimAnimationDuration == 7.5)
    }

    // MARK: - Formatted Display

    @Test("Break interval formatted string is correct")
    func intervalFormatting() {
        let (settings, _) = makeSUT()

        settings.breakIntervalMinutes = 1  // will clamp to 5
        #expect(settings.breakIntervalFormatted == "5 minutes")

        settings.breakIntervalMinutes = 20
        #expect(settings.breakIntervalFormatted == "20 minutes")
    }

    @Test("Break duration formatted string handles seconds and minutes")
    func durationFormatting() {
        let (settings, _) = makeSUT()

        settings.breakDurationSeconds = 20
        #expect(settings.breakDurationFormatted == "20 seconds")

        settings.breakDurationSeconds = 60
        #expect(settings.breakDurationFormatted == "1 minute")

        settings.breakDurationSeconds = 120
        #expect(settings.breakDurationFormatted == "2 minutes")

        settings.breakDurationSeconds = 90
        #expect(settings.breakDurationFormatted == "1m 30s")
    }
}
