import Foundation
import SwiftUI

/// Central settings model backed by UserDefaults.
///
/// After the multi-timer refactor, AppSettings only holds:
/// - The array of `BreakTimer` configurations (persisted as JSON)
/// - Global app preferences (launch at login)
///
/// All per-timer settings (interval, duration, appearance, schedule)
/// now live on individual `BreakTimer` instances.
@Observable
final class AppSettings {

    // MARK: - Storage

    private let defaults: UserDefaults

    // MARK: - Timers

    /// All user-defined break timers. Each is a fully self-contained configuration.
    var timers: [BreakTimer] {
        didSet { saveTimers() }
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load timers (or migrate from old format, or start fresh)
        self.timers = Self.loadTimers(from: defaults)
    }

    // MARK: - Timer CRUD Helpers

    /// Add a new timer and return it.
    @discardableResult
    func addTimer(_ timer: BreakTimer) -> BreakTimer {
        let validated = timer.validated()
        timers.append(validated)
        return validated
    }

    /// Update an existing timer by ID.
    func updateTimer(_ timer: BreakTimer) {
        let validated = timer.validated()
        if let index = timers.firstIndex(where: { $0.id == validated.id }) {
            timers[index] = validated
        }
    }

    /// Remove a timer by ID.
    func removeTimer(id: UUID) {
        timers.removeAll { $0.id == id }
    }

    // MARK: - Private: Persistence

    private func saveTimers() {
        guard let data = try? JSONEncoder().encode(timers) else { return }
        defaults.set(data, forKey: Keys.timers)
    }

    private static func loadTimers(from defaults: UserDefaults) -> [BreakTimer] {
        // Try loading the new format first
        if let data = defaults.data(forKey: Keys.timers) {
            if let timers = try? JSONDecoder().decode([BreakTimer].self, from: data) {
                return timers
            }
        }

        // Try migrating from old single-timer + schedules format
        if let migrated = migrateFromLegacy(defaults: defaults) {
            // Save migrated timers in new format
            if let data = try? JSONEncoder().encode(migrated) {
                defaults.set(data, forKey: Keys.timers)
            }
            // Clean up old keys
            cleanupLegacyKeys(defaults: defaults)
            return migrated
        }

        // Fresh install — no timers yet
        return []
    }

    // MARK: - Private: Migration

    /// Migrate from the old single-timer AppSettings format.
    /// Returns nil if no old keys are found (fresh install).
    private static func migrateFromLegacy(defaults: UserDefaults) -> [BreakTimer]? {
        // Check if old keys exist
        guard defaults.object(forKey: LegacyKeys.breakIntervalMinutes) != nil else {
            return nil
        }

        let interval = defaults.integer(forKey: LegacyKeys.breakIntervalMinutes)
        let duration = defaults.integer(forKey: LegacyKeys.breakDurationSeconds)
        let showCountdown = defaults.bool(forKey: LegacyKeys.showCountdown)
        let playSound = defaults.bool(forKey: LegacyKeys.playSoundOnBreak)
        let dimDuration = defaults.double(forKey: LegacyKeys.dimAnimationDuration)
        let opacity = defaults.double(forKey: LegacyKeys.overlayOpacity)
        let colorHex = defaults.string(forKey: LegacyKeys.overlayColorHex) ?? "#000000"
        let message = defaults.string(forKey: LegacyKeys.breakMessage) ?? DesignTokens.defaultBreakMessage

        // Create a timer from the global settings
        let globalTimer = BreakTimer(
            id: UUID(),
            name: "Break Timer",
            isEnabled: true,
            breakIntervalMinutes: interval > 0 ? interval : DesignTokens.defaultBreakIntervalMinutes,
            breakDurationSeconds: duration > 0 ? duration : DesignTokens.defaultBreakDurationSeconds,
            overlayColorHex: colorHex,
            overlayOpacity: opacity > 0 ? opacity : DesignTokens.overlayDefaultOpacity,
            breakMessage: message,
            dimAnimationDuration: dimDuration > 0 ? dimDuration : DesignTokens.overlayDimDuration,
            showCountdown: showCountdown,
            playSoundOnBreak: playSound,
            activeDays: [1, 2, 3, 4, 5, 6, 7],
            startHour: 0,
            startMinute: 0,
            endHour: 23,
            endMinute: 59
        )

        var result = [globalTimer.validated()]

        // Also migrate old BreakSchedule entries as separate timers
        if defaults.bool(forKey: LegacyKeys.useSchedules),
           let scheduleData = defaults.data(forKey: LegacyKeys.schedules),
           let schedules = try? JSONDecoder().decode([BreakSchedule].self, from: scheduleData) {
            for schedule in schedules {
                let timer = BreakTimer(
                    id: UUID(),
                    name: schedule.name,
                    isEnabled: schedule.isEnabled,
                    breakIntervalMinutes: schedule.breakIntervalMinutes,
                    breakDurationSeconds: schedule.breakDurationSeconds,
                    overlayColorHex: colorHex,
                    overlayOpacity: opacity > 0 ? opacity : DesignTokens.overlayDefaultOpacity,
                    breakMessage: message,
                    dimAnimationDuration: dimDuration > 0 ? dimDuration : DesignTokens.overlayDimDuration,
                    showCountdown: showCountdown,
                    playSoundOnBreak: playSound,
                    activeDays: schedule.activeDays,
                    startHour: schedule.startHour,
                    startMinute: schedule.startMinute,
                    endHour: schedule.endHour,
                    endMinute: schedule.endMinute
                )
                result.append(timer.validated())
            }
        }

        return result
    }

    private static func cleanupLegacyKeys(defaults: UserDefaults) {
        for key in LegacyKeys.all {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let timers = "breakTimers_v2"
    }

    /// Keys from the old single-timer format, used only for migration.
    private enum LegacyKeys {
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

        static let all = [
            breakIntervalMinutes, breakDurationSeconds, showCountdown,
            playSoundOnBreak, dimAnimationDuration, overlayOpacity,
            overlayColorHex, breakMessage, schedules, useSchedules,
        ]
    }
}
