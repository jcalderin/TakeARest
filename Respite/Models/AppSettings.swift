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
        ])

        // Load persisted values (or registered defaults)
        self.breakIntervalMinutes = defaults.integer(forKey: Keys.breakIntervalMinutes)
        self.breakDurationSeconds = defaults.integer(forKey: Keys.breakDurationSeconds)
        self.showCountdown = defaults.bool(forKey: Keys.showCountdown)
        self.playSoundOnBreak = defaults.bool(forKey: Keys.playSoundOnBreak)
        self.dimAnimationDuration = defaults.double(forKey: Keys.dimAnimationDuration)
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

    private enum Keys {
        static let breakIntervalMinutes = "breakIntervalMinutes"
        static let breakDurationSeconds = "breakDurationSeconds"
        static let showCountdown = "showCountdown"
        static let playSoundOnBreak = "playSoundOnBreak"
        static let dimAnimationDuration = "dimAnimationDuration"
    }
}

// MARK: - Comparable Clamping

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
