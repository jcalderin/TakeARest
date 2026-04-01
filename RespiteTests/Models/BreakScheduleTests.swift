import Foundation
import Testing
@testable import Respite

/// Tests for BreakSchedule model.
@Suite("BreakSchedule")
struct BreakScheduleTests {

    // MARK: - Active Check

    @Test("Schedule is active on matching day and time")
    func activeOnMatchingDayAndTime() {
        let schedule = BreakSchedule.weekday() // Mon-Fri, 9:00-17:00

        // Wednesday at 10:00 AM
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1 // Wednesday
        components.hour = 10
        components.minute = 0
        let date = Calendar.current.date(from: components)!

        #expect(schedule.isActiveNow(date: date))
    }

    @Test("Schedule is inactive outside time range")
    func inactiveOutsideTimeRange() {
        let schedule = BreakSchedule.weekday() // Mon-Fri, 9:00-17:00

        // Wednesday at 8:00 AM (before start)
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1
        components.hour = 8
        components.minute = 0
        let earlyDate = Calendar.current.date(from: components)!
        #expect(!schedule.isActiveNow(date: earlyDate))

        // Wednesday at 18:00 (after end)
        components.hour = 18
        let lateDate = Calendar.current.date(from: components)!
        #expect(!schedule.isActiveNow(date: lateDate))
    }

    @Test("Schedule is inactive on non-matching day")
    func inactiveOnWrongDay() {
        let schedule = BreakSchedule.weekday() // Mon-Fri

        // Saturday at 10:00 AM
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 4 // Saturday
        components.hour = 10
        components.minute = 0
        let date = Calendar.current.date(from: components)!

        #expect(!schedule.isActiveNow(date: date))
    }

    @Test("Disabled schedule is never active")
    func disabledScheduleInactive() {
        var schedule = BreakSchedule.weekday()
        schedule.isEnabled = false

        // Wednesday at 10:00 AM — would match but disabled
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1
        components.hour = 10
        components.minute = 0
        let date = Calendar.current.date(from: components)!

        #expect(!schedule.isActiveNow(date: date))
    }

    // MARK: - Display Helpers

    @Test("Weekday schedule shows Mon–Fri")
    func weekdayDaysDescription() {
        let schedule = BreakSchedule.weekday()
        #expect(schedule.daysDescription == "Mon–Fri")
    }

    @Test("Weekend schedule shows Sat, Sun")
    func weekendDaysDescription() {
        let schedule = BreakSchedule.weekend()
        #expect(schedule.daysDescription == "Sat, Sun")
    }

    // MARK: - Codable

    @Test("Schedule round-trips through JSON")
    func codableRoundTrip() throws {
        let original = BreakSchedule.weekday()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BreakSchedule.self, from: data)

        #expect(decoded == original)
        #expect(decoded.name == "Weekday")
        #expect(decoded.activeDays == [2, 3, 4, 5, 6])
        #expect(decoded.breakIntervalMinutes == 20)
    }

    // MARK: - Effective Settings

    @Test("Active schedule overrides global settings")
    func activeScheduleOverridesGlobal() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.breakIntervalMinutes = 20
        settings.breakDurationSeconds = 20
        settings.useSchedules = true

        var schedule = BreakSchedule.weekday()
        schedule.breakIntervalMinutes = 45
        schedule.breakDurationSeconds = 60
        settings.schedules = [schedule]

        // Wednesday at 10:00 AM — schedule is active
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1
        components.hour = 10
        components.minute = 0
        let date = Calendar.current.date(from: components)!

        #expect(settings.effectiveIntervalMinutes(at: date) == 45)
        #expect(settings.effectiveDurationSeconds(at: date) == 60)
    }

    @Test("Global settings used when no schedule matches")
    func fallbackToGlobalSettings() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.breakIntervalMinutes = 25
        settings.breakDurationSeconds = 30
        settings.useSchedules = true

        let schedule = BreakSchedule.weekday() // Mon-Fri, 9-17
        settings.schedules = [schedule]

        // Saturday at 10:00 AM — no schedule matches
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 4 // Saturday
        components.hour = 10
        components.minute = 0
        let date = Calendar.current.date(from: components)!

        #expect(settings.effectiveIntervalMinutes(at: date) == 25)
        #expect(settings.effectiveDurationSeconds(at: date) == 30)
    }
}
