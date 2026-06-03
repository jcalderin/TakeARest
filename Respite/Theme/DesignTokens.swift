import SwiftUI

// MARK: - Design Tokens
// Respite's single source of truth for visual constants.
// All views reference these tokens — never hardcode colors, spacing, or typography.

enum DesignTokens {

    // MARK: - Colors

    /// Primary brand color — calm blue used for active states and accents
    static let primaryBlue = Color("PrimaryBlue")

    /// Success/completion — soft green for "break complete" states
    static let accentGreen = Color("AccentGreen")

    /// Warning/attention — warm orange for alerts and limits
    static let warmOrange = Color("WarmOrange")

    /// Overlay background — the default break screen tint
    static let overlayBackground = Color("OverlayBackground")

    /// Primary text on overlay
    static let overlayText = Color.white

    /// Secondary/muted text
    static let secondaryText = Color.secondary

    // MARK: - Spacing (4pt grid)

    /// 4pt — tightest spacing, icon padding
    static let spacing2XS: CGFloat = 4

    /// 8pt — compact spacing between related elements
    static let spacingXS: CGFloat = 8

    /// 12pt — default inner padding
    static let spacingSM: CGFloat = 12

    /// 16pt — standard spacing between elements
    static let spacingMD: CGFloat = 16

    /// 24pt — section separation
    static let spacingLG: CGFloat = 24

    /// 32pt — major section gaps
    static let spacingXL: CGFloat = 32

    /// 48pt — page-level margins
    static let spacing2XL: CGFloat = 48

    // MARK: - Corner Radius

    /// 8pt — cards, buttons
    static let cornerRadiusSM: CGFloat = 8

    /// 12pt — panels, sheets
    static let cornerRadiusMD: CGFloat = 12

    /// 16pt — large containers
    static let cornerRadiusLG: CGFloat = 16

    // MARK: - Animation

    /// Standard UI transition duration
    static let animationStandard: Double = 0.3

    /// Overlay dim-in animation (calming, not abrupt)
    static let overlayDimDuration: Double = 5.0

    /// Maximum overlay dim duration
    static let overlayDimDurationMax: Double = 15.0

    // MARK: - Typography Sizes

    /// Large title — overlay countdown, hero text
    static let fontSizeHero: CGFloat = 64

    /// Section title
    static let fontSizeTitle: CGFloat = 24

    /// Subtitle / section header
    static let fontSizeSubtitle: CGFloat = 18

    /// Body text
    static let fontSizeBody: CGFloat = 14

    /// Caption / hint text
    static let fontSizeCaption: CGFloat = 12

    // MARK: - Overlay Defaults

    /// Default overlay opacity (0.0 - 1.0)
    static let overlayDefaultOpacity: Double = 0.85

    /// Minimum overlay opacity users can set
    static let overlayMinOpacity: Double = 0.5

    /// Maximum overlay opacity users can set
    static let overlayMaxOpacity: Double = 1.0

    /// Default break message
    static let defaultBreakMessage = "Time for a break"

    // MARK: - Timer Defaults

    /// Default break interval in minutes
    static let defaultBreakIntervalMinutes = 20

    /// Default break duration in seconds
    static let defaultBreakDurationSeconds = 20

    /// Minimum break interval in minutes
    static let minBreakIntervalMinutes = 5

    /// Maximum break interval in minutes (12 hours, to support "every N hours")
    static let maxBreakIntervalMinutes = 720

    /// Minimum break duration in seconds
    static let minBreakDurationSeconds = 10

    /// Maximum break duration in seconds
    static let maxBreakDurationSeconds = 300

    // MARK: - Timer Coordination

    /// How close two breaks must fire to be treated as coincident, so a
    /// "covered" timer's break is suppressed by its covering timer. Generous
    /// enough to absorb per-engine tick jitter and the wake grace period, yet
    /// far below the 5-minute minimum interval so it can't suppress a genuinely
    /// later occurrence.
    static let coverageCoincidenceWindow: TimeInterval = 90
}
