import SwiftUI
import ServiceManagement

/// General preferences tab — break intervals, durations, and launch-at-login.
struct GeneralTab: View {
    @Bindable var settings: AppSettings

    /// Login state is read from SMAppService, not from settings,
    /// because the user can change it externally in System Settings.
    @State private var launchAtLogin = LaunchAtLoginService.isEnabled

    var body: some View {
        Form {
            // MARK: - Break Timing
            Section {
                Stepper(
                    "Break every **\(settings.breakIntervalFormatted)**",
                    value: $settings.breakIntervalMinutes,
                    in: DesignTokens.minBreakIntervalMinutes...DesignTokens.maxBreakIntervalMinutes,
                    step: 5
                )

                Stepper(
                    "Break lasts **\(settings.breakDurationFormatted)**",
                    value: $settings.breakDurationSeconds,
                    in: DesignTokens.minBreakDurationSeconds...DesignTokens.maxBreakDurationSeconds,
                    step: 10
                )

                Slider(
                    value: $settings.dimAnimationDuration,
                    in: 1.0...DesignTokens.overlayDimDurationMax,
                    step: 0.5
                ) {
                    Text("Fade-in duration")
                } minimumValueLabel: {
                    Text("1s")
                        .respiteCaption()
                } maximumValueLabel: {
                    Text("15s")
                        .respiteCaption()
                }
            } header: {
                Text("Break Timing")
            }

            // MARK: - Behavior
            Section {
                Toggle("Show countdown during breaks", isOn: $settings.showCountdown)

                Toggle("Play sound when break starts", isOn: $settings.playSoundOnBreak)
            } header: {
                Text("Behavior")
            }

            // MARK: - Startup
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
            // Re-sync in case the user toggled it externally
            launchAtLogin = LaunchAtLoginService.isEnabled
        }
    }
}
