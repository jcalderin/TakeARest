import AppKit
import SwiftUI
import Testing
@testable import Respite

@Suite("Respite")
struct RespiteTests {

    @Test("All named colors exist in asset catalog")
    func namedColorsExist() {
        let colorNames = ["PrimaryBlue", "AccentGreen", "WarmOrange", "OverlayBackground"]
        for name in colorNames {
            let nsColor = NSColor(named: NSColor.Name(name))
            #expect(nsColor != nil, "Color '\(name)' not found in asset catalog")
        }
    }

    @Test("Design tokens have valid spacing values on 4pt grid")
    func spacingGridAlignment() {
        let spacings: [CGFloat] = [
            DesignTokens.spacing2XS,
            DesignTokens.spacingXS,
            DesignTokens.spacingSM,
            DesignTokens.spacingMD,
            DesignTokens.spacingLG,
            DesignTokens.spacingXL,
            DesignTokens.spacing2XL,
        ]
        for spacing in spacings {
            #expect(
                spacing.truncatingRemainder(dividingBy: 4) == 0,
                "Spacing \(spacing) is not on the 4pt grid"
            )
        }
    }

    @Test("Design tokens have valid timer defaults")
    func timerDefaults() {
        #expect(DesignTokens.defaultBreakIntervalMinutes >= DesignTokens.minBreakIntervalMinutes)
        #expect(DesignTokens.defaultBreakIntervalMinutes <= DesignTokens.maxBreakIntervalMinutes)
        #expect(DesignTokens.defaultBreakDurationSeconds >= DesignTokens.minBreakDurationSeconds)
        #expect(DesignTokens.defaultBreakDurationSeconds <= DesignTokens.maxBreakDurationSeconds)
    }

    @Test("Design tokens have valid overlay opacity range")
    func overlayOpacityRange() {
        #expect(DesignTokens.overlayMinOpacity > 0)
        #expect(DesignTokens.overlayMaxOpacity <= 1.0)
        #expect(DesignTokens.overlayMinOpacity < DesignTokens.overlayMaxOpacity)
        #expect(DesignTokens.overlayDefaultOpacity >= DesignTokens.overlayMinOpacity)
        #expect(DesignTokens.overlayDefaultOpacity <= DesignTokens.overlayMaxOpacity)
    }
}
