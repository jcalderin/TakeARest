import SwiftUI

/// General preferences tab — break intervals, durations, and launch-at-login.
///
/// Phase 3: Placeholder layout. Phase 4 wires up AppSettings.
struct GeneralTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            Text("General")
                .respiteTitle()

            Text("Configure break intervals, durations, and startup behavior.")
                .respiteBody()
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignTokens.spacingLG)
    }
}
