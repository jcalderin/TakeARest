import SwiftUI

/// A minimal overlay shown on secondary (non-main) displays.
///
/// Displays only the dark background and break message — no controls,
/// no countdown, no keyboard shortcuts. This avoids multiple key windows
/// fighting for focus.
struct SecondaryOverlayView: View {

    var body: some View {
        ZStack {
            Color.black
                .opacity(DesignTokens.overlayDefaultOpacity)
                .ignoresSafeArea()

            Text(DesignTokens.defaultBreakMessage)
                .font(.system(size: 40, weight: .light, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
