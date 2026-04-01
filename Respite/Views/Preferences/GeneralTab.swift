import SwiftUI
import ServiceManagement

/// General preferences tab — launch at login only.
///
/// All per-timer settings (timing, appearance, schedule) now live
/// on individual BreakTimer instances, edited in the Timers tab.
struct GeneralTab: View {

    /// Login state is read from SMAppService, not from settings,
    /// because the user can change it externally in System Settings.
    @State private var launchAtLogin = LaunchAtLoginService.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch Respite at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLoginService.setEnabled(newValue)
                    }
            } header: {
                Text("Startup")
            } footer: {
                if SMAppService.mainApp.status == .requiresApproval {
                    Text("Respite needs approval in System Settings > General > Login Items.")
                        .respiteCaption()
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = LaunchAtLoginService.isEnabled
        }
    }
}
