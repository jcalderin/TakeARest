import SwiftUI

/// A minimal overlay shown on secondary (non-main) displays.
///
/// Displays only the dark background and break message — no controls,
/// no countdown, no keyboard shortcuts. This avoids multiple key windows
/// fighting for focus. Reads appearance settings from AppSettings.
struct SecondaryOverlayView: View {
    var settings: AppSettings

    var body: some View {
        ZStack {
            settings.overlayColor
                .opacity(settings.overlayOpacity)
                .ignoresSafeArea()

            Text(settings.breakMessage)
                .font(.system(size: 40, weight: .light, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
