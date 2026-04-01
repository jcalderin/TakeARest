import SwiftUI

/// About tab — app info, version, credits, links.
///
/// Phase 3: Placeholder layout. Phase 12 completes with full content.
struct AboutTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            Text("About")
                .respiteTitle()

            Text("Respite is an open-source break reminder for macOS.")
                .respiteBody()
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignTokens.spacingLG)
    }
}
