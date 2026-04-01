import SwiftUI

/// Root preferences view with tabbed navigation.
///
/// Uses the native macOS tab style for a platform-consistent look.
/// Each tab is a separate view that will be wired up in later phases.
struct PreferencesView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralTab()
            }

            Tab("Appearance", systemImage: "paintbrush") {
                AppearanceTab()
            }

            Tab("Schedules", systemImage: "calendar.badge.clock") {
                SchedulesTab()
            }

            Tab("About", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(
            minWidth: 480,
            idealWidth: 520,
            minHeight: 360,
            idealHeight: 400
        )
    }
}
