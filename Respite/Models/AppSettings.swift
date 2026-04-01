import Foundation
import SwiftUI

/// Central settings model backed by UserDefaults.
///
/// All user-configurable preferences live here. Views bind to this
/// via `@Bindable` and services read from it directly.
/// Uses `@Observable` (macOS 14+) for clean SwiftUI integration.
@Observable
final class AppSettings {

    // MARK: - Storage

    private let defaults: UserDefaults

    // MARK: - General Settings

    /// Minutes between breaks (5–120)
    var breakIntervalMinutes: Int {
        didSet {
            let clamped = breakIntervalMinutes.clamped(
                to: DesignTokens.minBreakIntervalMinutes...DesignTokens.maxBreakIntervalMinutes
            )
            if breakIntervalMinutes != clamped { breakIntervalMinutes = clamped }
            defaults.set(clamped, forKey: Keys.breakIntervalMinutes)
        }
    }

    /// Seconds each break lasts (10–300)
    var breakDurationSeconds: Int {
        didSet {
            let clamped = breakDurationSeconds.clamped(
                to: DesignTokens.minBreakDurationSeconds...DesignTokens.maxBreakDurationSeconds
            )
            if breakDurationSeconds != clamped { breakDurationSeconds = clamped }
            defaults.set(clamped, forKey: Keys.breakDurationSeconds)
        }
    }

    /// Show a countdown timer during breaks
    var showCountdown: Bool {
        didSet { defaults.set(showCountdown, forKey: Keys.showCountdown) }
    }

    /// Play a sound when a break starts
    var playSoundOnBreak: Bool {
        didSet { defaults.set(playSoundOnBreak, forKey: Keys.playSoundOnBreak) }
    }

    /// Duration of the dim-in animation in seconds (1–15)
    var dimAnimationDuration: Double {
        didSet {
            let clamped = dimAnimationDuration.clamped(to: 1.0...DesignTokens.overlayDimDurationMax)
            if dimAnimationDuration != clamped { dimAnimationDuration = clamped }
            defaults.set(clamped, forKey: Keys.dimAnimationDuration)
        }
    }

    // MARK: - Appearance Settings

    /// Overlay background opacity (0.5–1.0)
    var overlayOpacity: Double {
        didSet {
            let clamped = overlayOpacity.clamped(
                to: DesignTokens.overlayMinOpacity...DesignTokens.overlayMaxOpacity
            )
            if overlayOpacity != clamped { overlayOpacity = clamped }
            defaults.set(clamped, forKey: Keys.overlayOpacity)
        }
    }

    /// Overlay background color stored as hex string (e.g. "#1A1A2E")
    var overlayColorHex: String {
        didSet { defaults.set(overlayColorHex, forKey: Keys.overlayColorHex) }
    }

    /// Custom break message shown on the overlay
    var breakMessage: String {
        didSet { defaults.set(breakMessage, forKey: Keys.breakMessage) }
    }

    /// Resolved overlay color from the hex string
    var overlayColor: Color {
        get { Color(hex: overlayColorHex) ?? .black }
        set { overlayColorHex = newValue.toHex() ?? "#000000" }
    }

    // MARK: - Schedules

    /// User-defined break schedules. When empty, global settings are used.
    var schedules: [BreakSchedule] {
        didSet { saveSchedules() }
    }

    /// Whether to use schedules instead of global break timing.
    var useSchedules: Bool {
        didSet { defaults.set(useSchedules, forKey: Keys.useSchedules) }
    }

    /// Returns the currently active schedule based on day and time, or nil if none match.
    func activeSchedule(at date: Date = Date()) -> BreakSchedule? {
        guard useSchedules else { return nil }
        return schedules.first { $0.isActiveNow(date: date) }
    }

    /// Effective break interval — from active schedule or global setting.
    func effectiveIntervalMinutes(at date: Date = Date()) -> Int {
        activeSchedule(at: date)?.breakIntervalMinutes ?? breakIntervalMinutes
    }

    /// Effective break duration — from active schedule or global setting.
    func effectiveDurationSeconds(at date: Date = Date()) -> Int {
        activeSchedule(at: date)?.breakDurationSeconds ?? breakDurationSeconds
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Register factory defaults so first launch has sensible values
        defaults.register(defaults: [
            Keys.breakIntervalMinutes: DesignTokens.defaultBreakIntervalMinutes,
            Keys.breakDurationSeconds: DesignTokens.defaultBreakDurationSeconds,
            Keys.showCountdown: true,
            Keys.playSoundOnBreak: false,
            Keys.dimAnimationDuration: DesignTokens.overlayDimDuration,
            Keys.overlayOpacity: DesignTokens.overlayDefaultOpacity,
            Keys.overlayColorHex: "#000000",
            Keys.breakMessage: DesignTokens.defaultBreakMessage,
            Keys.useSchedules: false,
        ])

        // Load persisted values (or registered defaults)
        self.breakIntervalMinutes = defaults.integer(forKey: Keys.breakIntervalMinutes)
        self.breakDurationSeconds = defaults.integer(forKey: Keys.breakDurationSeconds)
        self.showCountdown = defaults.bool(forKey: Keys.showCountdown)
        self.playSoundOnBreak = defaults.bool(forKey: Keys.playSoundOnBreak)
        self.dimAnimationDuration = defaults.double(forKey: Keys.dimAnimationDuration)
        self.overlayOpacity = defaults.double(forKey: Keys.overlayOpacity)
        self.overlayColorHex = defaults.string(forKey: Keys.overlayColorHex) ?? "#000000"
        self.breakMessage = defaults.string(forKey: Keys.breakMessage) ?? DesignTokens.defaultBreakMessage
        self.useSchedules = defaults.bool(forKey: Keys.useSchedules)
        self.schedules = Self.loadSchedules(from: defaults)
    }

    // MARK: - Formatted Display Helpers

    /// Break interval as a human-readable string, e.g. "20 minutes"
    var breakIntervalFormatted: String {
        breakIntervalMinutes == 1 ? "1 minute" : "\(breakIntervalMinutes) minutes"
    }

    /// Break duration as a human-readable string, e.g. "20 seconds"
    var breakDurationFormatted: String {
        if breakDurationSeconds >= 60 {
            let mins = breakDurationSeconds / 60
            let secs = breakDurationSeconds % 60
            if secs == 0 {
                return mins == 1 ? "1 minute" : "\(mins) minutes"
            }
            return "\(mins)m \(secs)s"
        }
        return breakDurationSeconds == 1 ? "1 second" : "\(breakDurationSeconds) seconds"
    }

    // MARK: - Keys

    // MARK: - Private: Schedule Persistence

    private func saveSchedules() {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        defaults.set(data, forKey: Keys.schedules)
    }

    private static func loadSchedules(from defaults: UserDefaults) -> [BreakSchedule] {
        guard let data = defaults.data(forKey: Keys.schedules) else { return [] }
        return (try? JSONDecoder().decode([BreakSchedule].self, from: data)) ?? []
    }

    private enum Keys {
        static let breakIntervalMinutes = "breakIntervalMinutes"
        static let breakDurationSeconds = "breakDurationSeconds"
        static let showCountdown = "showCountdown"
        static let playSoundOnBreak = "playSoundOnBreak"
        static let dimAnimationDuration = "dimAnimationDuration"
        static let overlayOpacity = "overlayOpacity"
        static let overlayColorHex = "overlayColorHex"
        static let breakMessage = "breakMessage"
        static let schedules = "schedules"
        static let useSchedules = "useSchedules"
    }
}

// MARK: - Comparable Clamping

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
