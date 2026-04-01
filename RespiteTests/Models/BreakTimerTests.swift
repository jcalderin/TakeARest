import Foundation
import SwiftUI
import Testing
@testable import Respite

/// Tests for BreakTimer model.
///
/// Alyce's edge case coverage: schedule boundaries, disabled states,
/// empty days, validation clamping, codable round-trips, factory presets.
@Suite("BreakTimer")
struct BreakTimerTests {

    // MARK: - Helpers

    /// Create a date for a known weekday and time.
    /// - Parameters:
    ///   - year: The year (default 2026)
    ///   - month: The month (default 4 = April)
    ///   - day: The day of the month
    ///   - hour: Hour (0-23)
    ///   - minute: Minute (0-59)
    private func makeDate(
        year: Int = 2026, month: Int = 4, day: Int, hour: Int, minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    // MARK: - Schedule: Active Checks

    @Test("Timer is active on matching day and time")
    func activeOnMatchingDayAndTime() {
        let timer = BreakTimer.screenBreak() // Mon-Fri, 9:00-13:00

        // Wednesday April 1 2026 at 10:00 AM
        let date = makeDate(day: 1, hour: 10)
        #expect(timer.isScheduledActive(at: date))
    }

    @Test("Timer is inactive before start time")
    func inactiveBeforeStartTime() {
        let timer = BreakTimer.screenBreak() // starts at 9:00

        // Wednesday at 8:59 AM
        let date = makeDate(day: 1, hour: 8, minute: 59)
        #expect(!timer.isScheduledActive(at: date))
    }

    @Test("Timer is active at exact start time boundary")
    func activeAtExactStartTime() {
        let timer = BreakTimer.screenBreak() // starts at 9:00

        // Wednesday at 9:00 AM exactly
        let date = makeDate(day: 1, hour: 9, minute: 0)
        #expect(timer.isScheduledActive(at: date))
    }

    @Test("Timer is inactive at exact end time boundary")
    func inactiveAtExactEndTime() {
        let timer = BreakTimer.screenBreak() // ends at 13:00

        // Wednesday at 1:00 PM exactly — end is exclusive
        let date = makeDate(day: 1, hour: 13, minute: 0)
        #expect(!timer.isScheduledActive(at: date))
    }

    @Test("Timer is active one minute before end time")
    func activeOneMinuteBeforeEnd() {
        let timer = BreakTimer.screenBreak() // ends at 13:00

        // Wednesday at 12:59 PM
        let date = makeDate(day: 1, hour: 12, minute: 59)
        #expect(timer.isScheduledActive(at: date))
    }

    @Test("Timer is inactive on non-matching day")
    func inactiveOnWrongDay() {
        let timer = BreakTimer.screenBreak() // Mon-Fri only

        // Saturday April 4 2026 at 10:00 AM
        let date = makeDate(day: 4, hour: 10)
        #expect(!timer.isScheduledActive(at: date))
    }

    @Test("Disabled timer is never active")
    func disabledTimerAlwaysInactive() {
        var timer = BreakTimer.screenBreak()
        timer.isEnabled = false

        // Wednesday at 10:00 AM — would match but disabled
        let date = makeDate(day: 1, hour: 10)
        #expect(!timer.isScheduledActive(at: date))
    }

    @Test("Timer with empty activeDays is never active")
    func emptyDaysNeverActive() {
        var timer = BreakTimer.screenBreak()
        timer.activeDays = []

        let date = makeDate(day: 1, hour: 10)
        #expect(!timer.isScheduledActive(at: date))
    }

    @Test("All-day timer is active from midnight to 23:59")
    func allDaySchedule() {
        var timer = BreakTimer.screenBreak()
        timer.activeDays = [1, 2, 3, 4, 5, 6, 7]
        timer.startHour = 0
        timer.startMinute = 0
        timer.endHour = 23
        timer.endMinute = 59

        // Wednesday at midnight
        let midnight = makeDate(day: 1, hour: 0, minute: 0)
        #expect(timer.isScheduledActive(at: midnight))

        // Wednesday at 11:58 PM
        let lateNight = makeDate(day: 1, hour: 23, minute: 58)
        #expect(timer.isScheduledActive(at: lateNight))

        // 23:59 is the end — exclusive, so inactive
        let endBoundary = makeDate(day: 1, hour: 23, minute: 59)
        #expect(!timer.isScheduledActive(at: endBoundary))
    }

    // MARK: - Display Helpers

    @Test("Weekday days description shows Mon–Fri")
    func weekdayDaysDescription() {
        let timer = BreakTimer.screenBreak()
        #expect(timer.daysDescription == "Mon–Fri")
    }

    @Test("Weekend days description shows Sat, Sun")
    func weekendDaysDescription() {
        var timer = BreakTimer.screenBreak()
        timer.activeDays = [1, 7]
        #expect(timer.daysDescription == "Sat, Sun")
    }

    @Test("All days description shows Every day")
    func allDaysDescription() {
        var timer = BreakTimer.screenBreak()
        timer.activeDays = [1, 2, 3, 4, 5, 6, 7]
        #expect(timer.daysDescription == "Every day")
    }

    @Test("Empty days description shows No days")
    func emptyDaysDescription() {
        var timer = BreakTimer.screenBreak()
        timer.activeDays = []
        #expect(timer.daysDescription == "No days")
    }

    @Test("Interval formatted shows correct text")
    func intervalFormatting() {
        var timer = BreakTimer.screenBreak()
        timer.breakIntervalMinutes = 20
        #expect(timer.intervalFormatted == "20 min")

        timer.breakIntervalMinutes = 1
        #expect(timer.intervalFormatted == "1 min")
    }

    @Test("Duration formatted handles seconds and minutes")
    func durationFormatting() {
        var timer = BreakTimer.screenBreak()

        timer.breakDurationSeconds = 20
        #expect(timer.durationFormatted == "20s")

        timer.breakDurationSeconds = 60
        #expect(timer.durationFormatted == "1 min")

        timer.breakDurationSeconds = 120
        #expect(timer.durationFormatted == "2 min")

        timer.breakDurationSeconds = 90
        #expect(timer.durationFormatted == "1m 30s")
    }

    // MARK: - Validation

    @Test("Validated clamps interval to valid range")
    func validationClampsInterval() {
        var timer = BreakTimer.screenBreak()

        timer.breakIntervalMinutes = 1
        let validated = timer.validated()
        #expect(validated.breakIntervalMinutes == DesignTokens.minBreakIntervalMinutes)

        timer.breakIntervalMinutes = 999
        let validated2 = timer.validated()
        #expect(validated2.breakIntervalMinutes == DesignTokens.maxBreakIntervalMinutes)
    }

    @Test("Validated clamps duration to valid range")
    func validationClampsDuration() {
        var timer = BreakTimer.screenBreak()

        timer.breakDurationSeconds = 1
        #expect(timer.validated().breakDurationSeconds == DesignTokens.minBreakDurationSeconds)

        timer.breakDurationSeconds = 999
        #expect(timer.validated().breakDurationSeconds == DesignTokens.maxBreakDurationSeconds)
    }

    @Test("Validated clamps opacity to valid range")
    func validationClampsOpacity() {
        var timer = BreakTimer.screenBreak()

        timer.overlayOpacity = 0.1
        #expect(timer.validated().overlayOpacity == DesignTokens.overlayMinOpacity)

        timer.overlayOpacity = 2.0
        #expect(timer.validated().overlayOpacity == DesignTokens.overlayMaxOpacity)
    }

    @Test("Validated strips invalid weekday numbers")
    func validationStripsInvalidDays() {
        var timer = BreakTimer.screenBreak()
        timer.activeDays = [0, 1, 3, 8, 99]
        let validated = timer.validated()
        #expect(validated.activeDays == [1, 3])
    }

    // MARK: - Codable

    @Test("BreakTimer round-trips through JSON")
    func codableRoundTrip() throws {
        let original = BreakTimer.screenBreak()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BreakTimer.self, from: data)

        #expect(decoded == original)
        #expect(decoded.name == "Screen Break")
        #expect(decoded.breakIntervalMinutes == 20)
        #expect(decoded.overlayColorHex == "#0A1628")
        #expect(decoded.breakMessage == "Look away from the screen")
        #expect(decoded.activeDays == [2, 3, 4, 5, 6])
    }

    @Test("Array of BreakTimers round-trips through JSON")
    func arrayCodeableRoundTrip() throws {
        let timers = [BreakTimer.screenBreak(), BreakTimer.standUpAndWalk()]
        let data = try JSONEncoder().encode(timers)
        let decoded = try JSONDecoder().decode([BreakTimer].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].name == "Screen Break")
        #expect(decoded[1].name == "Stand Up & Walk")
    }

    // MARK: - Factory Presets

    @Test("Screen break preset has sensible defaults")
    func screenBreakPreset() {
        let timer = BreakTimer.screenBreak()
        #expect(timer.isEnabled)
        #expect(timer.breakIntervalMinutes == 20)
        #expect(timer.breakDurationSeconds == 20)
        #expect(timer.activeDays == [2, 3, 4, 5, 6]) // Mon-Fri
        #expect(timer.startHour == 9)
        #expect(timer.endHour == 13)
        #expect(!timer.breakMessage.isEmpty)
    }

    @Test("Stand up preset has different config from screen break")
    func standUpPreset() {
        let timer = BreakTimer.standUpAndWalk()
        #expect(timer.isEnabled)
        #expect(timer.breakIntervalMinutes == 60)
        #expect(timer.breakDurationSeconds == 60)
        #expect(timer.playSoundOnBreak == true)
        #expect(timer.overlayColorHex != BreakTimer.screenBreak().overlayColorHex)
        #expect(timer.breakMessage != BreakTimer.screenBreak().breakMessage)
    }

    // MARK: - Color

    @Test("Overlay color resolves from hex")
    func overlayColorFromHex() {
        var timer = BreakTimer.screenBreak()
        timer.overlayColorHex = "#FF0000"
        // Just verify it doesn't crash — Color comparison is tricky
        _ = timer.overlayColor
    }

    @Test("Invalid hex falls back to black")
    func invalidHexFallsBackToBlack() {
        var timer = BreakTimer.screenBreak()
        timer.overlayColorHex = "not-a-color"
        // Should fall back to black without crashing
        _ = timer.overlayColor
    }
}
