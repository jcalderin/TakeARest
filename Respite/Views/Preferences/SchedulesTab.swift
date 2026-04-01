import SwiftUI

/// Schedules preferences tab — manage break schedules for different days/times.
///
/// Phase 3: Placeholder layout. Phase 10 adds schedule management UI.
struct SchedulesTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            Text("Schedules")
                .respiteTitle()

            Text("Create schedules for weekdays, weekends, or custom time ranges with different break intervals.")
                .respiteBody()
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignTokens.spacingLG)
    }
}
