import Foundation

/// A break schedule that applies on specific days during specific hours.
///
/// When multiple schedules are defined, the first matching one (by day and time)
/// determines the break interval and duration. If none match, the global
/// settings in AppSettings are used as a fallback.
struct BreakSchedule: Identifiable, Codable, Equatable, Sendable {

    var id: UUID
    var name: String

    /// Days of the week when this schedule is active.
    /// Uses Calendar weekday numbering: 1 = Sunday, 7 = Saturday.
    var activeDays: Set<Int>

    /// Minutes between breaks for this schedule (5–120)
    var breakIntervalMinutes: Int

    /// Seconds each break lasts for this schedule (10–300)
    var breakDurationSeconds: Int

    /// Start hour (0–23) of the active window
    var startHour: Int

    /// Start minute (0–59) of the active window
    var startMinute: Int

    /// End hour (0–23) of the active window
    var endHour: Int

    /// End minute (0–59) of the active window
    var endMinute: Int

    /// Whether this schedule is active
    var isEnabled: Bool

    // MARK: - Convenience

    /// Start time as total minutes since midnight
    var startTimeMinutes: Int { startHour * 60 + startMinute }

    /// End time as total minutes since midnight
    var endTimeMinutes: Int { endHour * 60 + endMinute }

    /// Whether this schedule applies right now based on day and time.
    func isActiveNow(date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return false }

        let weekday = calendar.component(.weekday, from: date)
        guard activeDays.contains(weekday) else { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute

        return currentMinutes >= startTimeMinutes && currentMinutes < endTimeMinutes
    }

    // MARK: - Display Helpers

    /// Human-readable days string, e.g. "Mon–Fri" or "Sat, Sun"
    var daysDescription: String {
        let weekdaySymbols = Calendar.current.shortWeekdaySymbols // ["Sun", "Mon", ...]
        let sortedDays = activeDays.sorted()

        // Check for common patterns
        let weekdays: Set<Int> = [2, 3, 4, 5, 6]
        let weekends: Set<Int> = [1, 7]
        let allDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

        if activeDays == weekdays { return "Mon–Fri" }
        if activeDays == weekends { return "Sat, Sun" }
        if activeDays == allDays { return "Every day" }

        return sortedDays.map { weekdaySymbols[$0 - 1] }.joined(separator: ", ")
    }

    /// Human-readable time range, e.g. "9:00 AM – 5:00 PM"
    var timeRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        var startComponents = DateComponents()
        startComponents.hour = startHour
        startComponents.minute = startMinute

        var endComponents = DateComponents()
        endComponents.hour = endHour
        endComponents.minute = endMinute

        let calendar = Calendar.current
        let startDate = calendar.date(from: startComponents) ?? Date()
        let endDate = calendar.date(from: endComponents) ?? Date()

        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    // MARK: - Factory

    /// A weekday schedule with default timing (Mon–Fri, 9 AM – 5 PM).
    static func weekday() -> BreakSchedule {
        BreakSchedule(
            id: UUID(),
            name: "Weekday",
            activeDays: [2, 3, 4, 5, 6],
            breakIntervalMinutes: 20,
            breakDurationSeconds: 20,
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            isEnabled: true
        )
    }

    /// A weekend schedule with relaxed timing (Sat–Sun, all day).
    static func weekend() -> BreakSchedule {
        BreakSchedule(
            id: UUID(),
            name: "Weekend",
            activeDays: [1, 7],
            breakIntervalMinutes: 30,
            breakDurationSeconds: 20,
            startHour: 0,
            startMinute: 0,
            endHour: 23,
            endMinute: 59,
            isEnabled: true
        )
    }
}
