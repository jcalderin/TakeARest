import SwiftUI

/// A minimal overlay shown on secondary (non-main) displays.
///
/// Uses the specific `BreakTimer`'s appearance for color, opacity, and message.
/// No controls or keyboard shortcuts — only the main screen handles interaction.
struct SecondaryOverlayView: View {
    var timer: BreakTimer

    var body: some View {
        ZStack {
            timer.overlayColor
                .opacity(timer.overlayOpacity)
                .ignoresSafeArea()

            Text(timer.breakMessage)
                .font(.system(size: 40, weight: .light, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
