import SwiftUI

/// Root preferences view with tabbed navigation.
///
/// After the multi-timer refactor:
/// - General: Launch at login only
/// - Timers: List/detail CRUD for all break timers
/// - About: App info, version, links
struct PreferencesView: View {
    var settings: AppSettings
    var timerManager: TimerManager

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralTab()
            }

            Tab("Timers", systemImage: "timer") {
                TimersTab(settings: settings, timerManager: timerManager)
            }

            Tab("About", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(
            minWidth: 560,
            idealWidth: 620,
            minHeight: 480,
            idealHeight: 540
        )
    }
}
