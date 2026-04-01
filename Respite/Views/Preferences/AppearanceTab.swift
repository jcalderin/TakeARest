import SwiftUI

/// Appearance preferences tab — overlay color, opacity, message, animation.
///
/// Phase 3: Placeholder layout. Phase 9 adds customization controls.
struct AppearanceTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            Text("Appearance")
                .respiteTitle()

            Text("Customize how break overlays look — colors, opacity, messages, and animations.")
                .respiteBody()
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignTokens.spacingLG)
    }
}
