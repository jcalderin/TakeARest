import Foundation
import SwiftUI

/// How (or whether) a timer warns you that a break is coming, so you can wrap up.
enum PreWarnStyle: String, Codable, Sendable, CaseIterable {
    case off        // no heads-up
    case pill       // centered countdown pill
    case hud        // centered countdown + Start now / Skip buttons
    case bar        // thin progress bar across the top edge
    case watermark  // large see-through countdown across all screens (click-through)

    var label: String {
        switch self {
        case .off: "Off"
        case .pill: "Pill"
        case .hud: "Buttons"
        case .bar: "Bar"
        case .watermark: "Watermark"
        }
    }

    /// Whether this style covers every screen (vs. just the active one).
    var spansAllScreens: Bool { self == .watermark }

    /// Whether clicks pass straight through to the app behind it.
    var isClickThrough: Bool { self != .hud }
}

/// A fully self-contained break timer configuration.
///
/// Each `BreakTimer` is an independent entity with its own timing, appearance,
/// schedule, and behavior settings. Multiple `BreakTimer` instances can run
/// concurrently, each managed by its own `TimerEngine`.
///
/// This is a pure value type — `Codable`, `Sendable`, `Equatable` — stored
/// as JSON in UserDefaults via `AppSettings.timers`.
struct BreakTimer: Identifiable, Codable, Equatable, Sendable {

    var id: UUID

    // MARK: - Identity

    /// User-visible name, e.g. "Screen Break", "Stand Up & Walk"
    var name: String

    /// Whether this timer is user-enabled. Disabled timers don't run
    /// regardless of their schedule.
    var isEnabled: Bool

    // MARK: - Timing

    /// Minutes between breaks (5–120)
    var breakIntervalMinutes: Int

    /// Seconds each break lasts (10–300)
    var breakDurationSeconds: Int

    // MARK: - Appearance

    /// Overlay background color as hex, e.g. "#1A1A2E"
    var overlayColorHex: String

    /// Overlay background opacity (0.5–1.0)
    var overlayOpacity: Double

    /// Message shown on the overlay during this timer's break
    var breakMessage: String

    /// Duration of the fade-in animation in seconds (1.0–15.0)
    var dimAnimationDuration: Double

    // MARK: - Behavior

    /// Show a countdown timer on the overlay during breaks
    var showCountdown: Bool

    /// Play a sound when this timer's break starts
    var playSoundOnBreak: Bool

    // MARK: - Schedule (Cron)

    /// Days of the week when this timer is active.
    /// Uses Calendar weekday numbering: 1 = Sunday, 7 = Saturday.
    var activeDays: Set<Int>

    /// Start hour of the active window (0–23)
    var startHour: Int

    /// Start minute of the active window (0–59)
    var startMinute: Int

    /// End hour of the active window (0–23)
    var endHour: Int

    /// End minute of the active window (0–59)
    var endMinute: Int

    // MARK: - Coordination

    /// IDs of other timers that "cover" this one. When a covering timer's break
    /// runs, this timer skips its coincident break that one time and keeps its
    /// own schedule. Empty by default.
    var coveredByTimerIDs: Set<UUID> = []

    /// The minute the wall-clock grid is aligned to (0–59). Breaks always fire
    /// on absolute clock times: the grid runs from midnight + `alignMinute`,
    /// stepping by `breakIntervalMinutes`. e.g. interval 20, align 0 →
    /// :00 / :20 / :40; interval 120, align 30 → 00:30 / 02:30 / …
    var alignMinute: Int = 0

    // MARK: - Pre-Warning

    /// How to warn that a break is imminent (or `.off`). Defaults to `.pill`.
    var preWarnStyle: PreWarnStyle = .pill

    /// How many seconds before the break the heads-up appears (5–300).
    var preWarnSeconds: Int = DesignTokens.preWarnDefaultSeconds

    // MARK: - Computed: Schedule

    /// Start time as total minutes since midnight.
    var startTimeMinutes: Int { startHour * 60 + startMinute }

    /// End time as total minutes since midnight.
    var endTimeMinutes: Int { endHour * 60 + endMinute }

    /// Whether this timer's schedule says it should be active right now.
    ///
    /// Checks three conditions:
    /// 1. `isEnabled` is true
    /// 2. Current weekday is in `activeDays`
    /// 3. Current time is within the start/end window
    ///
    /// - Parameters:
    ///   - date: The date to evaluate against. Defaults to now.
    ///   - calendar: The calendar to use for day/hour extraction.
    func isScheduledActive(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return false }
        guard !activeDays.isEmpty else { return false }

        let weekday = calendar.component(.weekday, from: date)
        guard activeDays.contains(weekday) else { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute

        return currentMinutes >= startTimeMinutes && currentMinutes < endTimeMinutes
    }

    // MARK: - Computed: Appearance

    /// Resolved overlay color from the hex string.
    var overlayColor: Color {
        Color(hex: overlayColorHex) ?? .black
    }

    // MARK: - Computed: Display Helpers

    /// Human-readable days string, e.g. "Mon–Fri" or "Sat, Sun"
    var daysDescription: String {
        let weekdaySymbols = Calendar.current.shortWeekdaySymbols // ["Sun", "Mon", ...]
        let sortedDays = activeDays.sorted()

        let weekdays: Set<Int> = [2, 3, 4, 5, 6]
        let weekends: Set<Int> = [1, 7]
        let allDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

        if activeDays == weekdays { return "Mon–Fri" }
        if activeDays == weekends { return "Sat, Sun" }
        if activeDays == allDays { return "Every day" }
        if activeDays.isEmpty { return "No days" }

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

    /// Break interval as a human-readable string, e.g. "20 min"
    var intervalFormatted: String {
        breakIntervalMinutes == 1 ? "1 min" : "\(breakIntervalMinutes) min"
    }

    /// Whether the interval is a whole number of hours (≥ 1h), so the cadence
    /// reads naturally as "every N hours".
    var isHourly: Bool {
        breakIntervalMinutes >= 60 && breakIntervalMinutes % 60 == 0
    }

    /// Mode-aware cadence string, e.g. "Every 20 min" or "Every 2 hr at :30".
    var cadenceDescription: String {
        if isHourly {
            let hrs = breakIntervalMinutes / 60
            let base = hrs == 1 ? "Every hour" : "Every \(hrs) hr"
            return alignMinute == 0 ? base : "\(base) at :\(String(format: "%02d", alignMinute))"
        }
        return "Every \(intervalFormatted)"
    }

    /// Plain-text clause describing exactly when breaks land, for a caption like
    /// "Fires \(firingPreview)". Shows users the real wall-clock times.
    var firingPreview: String {
        let interval = breakIntervalMinutes
        if interval < 60 && 60 % interval == 0 {
            let phase = alignMinute % interval
            let slots = stride(from: phase, to: 60, by: interval)
                .map { String(format: ":%02d", $0) }
            return "on the clock — \(slots.joined(separator: " · "))"
        }
        if isHourly {
            let hrs = breakIntervalMinutes / 60
            let every = hrs == 1 ? "every hour" : "every \(hrs) hours"
            return alignMinute == 0
                ? "\(every), on the hour"
                : "\(every), at :\(String(format: "%02d", alignMinute))"
        }
        // Non-divisor sub-hour interval: the grid drifts through the day.
        return "every \(interval) min, aligned to :\(String(format: "%02d", alignMinute % 60))"
    }

    /// Break duration as a human-readable string, e.g. "20s"
    var durationFormatted: String {
        if breakDurationSeconds >= 60 {
            let mins = breakDurationSeconds / 60
            let secs = breakDurationSeconds % 60
            if secs == 0 {
                return mins == 1 ? "1 min" : "\(mins) min"
            }
            return "\(mins)m \(secs)s"
        }
        return "\(breakDurationSeconds)s"
    }

    /// One-line summary, e.g. "Every 20 min, 20s break · Mon–Fri 9–5"
    var summaryDescription: String {
        "Every \(intervalFormatted), \(durationFormatted) break · \(daysDescription) \(timeRangeDescription)"
    }

    // MARK: - Validation

    /// Returns a copy with all fields clamped to their valid ranges.
    func validated() -> BreakTimer {
        var copy = self
        copy.breakIntervalMinutes = copy.breakIntervalMinutes.clamped(
            to: DesignTokens.minBreakIntervalMinutes...DesignTokens.maxBreakIntervalMinutes
        )
        copy.breakDurationSeconds = copy.breakDurationSeconds.clamped(
            to: DesignTokens.minBreakDurationSeconds...DesignTokens.maxBreakDurationSeconds
        )
        copy.overlayOpacity = copy.overlayOpacity.clamped(
            to: DesignTokens.overlayMinOpacity...DesignTokens.overlayMaxOpacity
        )
        copy.dimAnimationDuration = copy.dimAnimationDuration.clamped(
            to: 1.0...DesignTokens.overlayDimDurationMax
        )
        copy.startHour = copy.startHour.clamped(to: 0...23)
        copy.startMinute = copy.startMinute.clamped(to: 0...59)
        copy.endHour = copy.endHour.clamped(to: 0...23)
        copy.endMinute = copy.endMinute.clamped(to: 0...59)
        copy.activeDays = copy.activeDays.filter { (1...7).contains($0) }
        copy.alignMinute = copy.alignMinute.clamped(to: 0...59)
        copy.preWarnSeconds = copy.preWarnSeconds.clamped(
            to: DesignTokens.minPreWarnSeconds...DesignTokens.maxPreWarnSeconds
        )
        copy.coveredByTimerIDs.remove(copy.id) // a timer can't cover itself
        return copy
    }

    // MARK: - Factory Presets

    /// A screen break timer: short, frequent, calm blue overlay.
    /// Designed for "look away from the screen" breaks.
    static func screenBreak() -> BreakTimer {
        BreakTimer(
            id: UUID(),
            name: "Screen Break",
            isEnabled: true,
            breakIntervalMinutes: 20,
            breakDurationSeconds: 20,
            overlayColorHex: "#0A1628",
            overlayOpacity: 0.85,
            breakMessage: "Look away from the screen",
            dimAnimationDuration: 5.0,
            showCountdown: true,
            playSoundOnBreak: false,
            activeDays: [2, 3, 4, 5, 6],
            startHour: 9,
            startMinute: 0,
            endHour: 13,
            endMinute: 0
        )
    }

    /// A stand-up timer: longer interval, more prominent overlay.
    /// Designed for "stand up and walk around" breaks.
    static func standUpAndWalk() -> BreakTimer {
        BreakTimer(
            id: UUID(),
            name: "Stand Up & Walk",
            isEnabled: true,
            breakIntervalMinutes: 60,
            breakDurationSeconds: 60,
            overlayColorHex: "#1A2E0A",
            overlayOpacity: 0.90,
            breakMessage: "Stand up and walk around",
            dimAnimationDuration: 5.0,
            showCountdown: true,
            playSoundOnBreak: true,
            activeDays: [2, 3, 4, 5, 6],
            startHour: 13,
            startMinute: 0,
            endHour: 18,
            endMinute: 0
        )
    }
}

// MARK: - Backward-Compatible Codable
//
// Declared in an extension so the synthesized memberwise initializer is
// preserved (factory presets, AppSettings migration, and tests all use it).
//
// `init(from:)` decodes the original fields normally and the newer fields with
// `decodeIfPresent ?? default`, so timers saved before those fields existed
// (the data in `breakTimers_v2`) decode without throwing. It also migrates the
// retired `anchorToClock`/`anchorMinute` fields into `alignMinute`.
extension BreakTimer {

    enum CodingKeys: String, CodingKey {
        case id, name, isEnabled
        case breakIntervalMinutes, breakDurationSeconds
        case overlayColorHex, overlayOpacity, breakMessage, dimAnimationDuration
        case showCountdown, playSoundOnBreak
        case activeDays, startHour, startMinute, endHour, endMinute
        case coveredByTimerIDs, alignMinute
        case preWarnStyle, preWarnSeconds
    }

    /// Retired fields, read only to migrate old saved data. The new model is
    /// always clock-aligned, so `anchorToClock` is dropped and `anchorMinute`
    /// becomes `alignMinute`.
    private enum LegacyKeys: String, CodingKey {
        case anchorMinute
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        breakIntervalMinutes = try c.decode(Int.self, forKey: .breakIntervalMinutes)
        breakDurationSeconds = try c.decode(Int.self, forKey: .breakDurationSeconds)
        overlayColorHex = try c.decode(String.self, forKey: .overlayColorHex)
        overlayOpacity = try c.decode(Double.self, forKey: .overlayOpacity)
        breakMessage = try c.decode(String.self, forKey: .breakMessage)
        dimAnimationDuration = try c.decode(Double.self, forKey: .dimAnimationDuration)
        showCountdown = try c.decode(Bool.self, forKey: .showCountdown)
        playSoundOnBreak = try c.decode(Bool.self, forKey: .playSoundOnBreak)
        activeDays = try c.decode(Set<Int>.self, forKey: .activeDays)
        startHour = try c.decode(Int.self, forKey: .startHour)
        startMinute = try c.decode(Int.self, forKey: .startMinute)
        endHour = try c.decode(Int.self, forKey: .endHour)
        endMinute = try c.decode(Int.self, forKey: .endMinute)

        coveredByTimerIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .coveredByTimerIDs) ?? []

        // New saves use `alignMinute`; older saves carried `anchorMinute`.
        if let align = try c.decodeIfPresent(Int.self, forKey: .alignMinute) {
            alignMinute = align
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            alignMinute = try legacy.decodeIfPresent(Int.self, forKey: .anchorMinute) ?? 0
        }

        // Pre-warning — absent in pre-feature saved data; default to a 30s pill.
        preWarnStyle = try c.decodeIfPresent(PreWarnStyle.self, forKey: .preWarnStyle) ?? .pill
        preWarnSeconds = try c.decodeIfPresent(Int.self, forKey: .preWarnSeconds)
            ?? DesignTokens.preWarnDefaultSeconds
    }
}

// MARK: - Clamping Utility

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
