import SwiftUI

/// Root preferences view with tabbed navigation.
///
/// Uses the native macOS tab style for a platform-consistent look.
/// Settings are passed down to tabs that need them.
struct PreferencesView: View {
    var settings: AppSettings

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralTab(settings: settings)
            }

            Tab("Appearance", systemImage: "paintbrush") {
                AppearanceTab(settings: settings)
            }

            Tab("Schedules", systemImage: "calendar.badge.clock") {
                SchedulesTab(settings: settings)
            }

            Tab("About", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(
            minWidth: 480,
            idealWidth: 520,
            minHeight: 460,
            idealHeight: 500
        )
    }
}
