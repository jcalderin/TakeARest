import SwiftUI

/// The dropdown menu shown when clicking Respite's menubar icon.
struct MenuBarView: View {
    var timerService: TimerService

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // MARK: - Timer Status
        timerStatusSection

        Divider()

        // MARK: - Timer Controls
        timerControlsSection

        Divider()

        // MARK: - App Controls
        Button("About Respite") {
            showAboutPanel()
        }
        .keyboardShortcut("i", modifiers: [.command])

        Button("Preferences...") {
            openSettings()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit Respite") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }

    // MARK: - Timer Status Section

    @ViewBuilder
    private var timerStatusSection: some View {
        switch timerService.state {
        case .idle:
            Text("Timer not started")
                .foregroundStyle(.secondary)

        case .counting:
            Text("Next break in \(timerService.countdownFormatted)")

        case .onBreak:
            Text("On break — \(timerService.countdownFormatted) remaining")

        case .paused(let until):
            if let formatted = timerService.pauseRemainingFormatted {
                Text("Paused — resumes in \(formatted)")
            } else if until == nil {
                Text("Paused indefinitely")
            }
        }
    }

    // MARK: - Timer Controls Section

    @ViewBuilder
    private var timerControlsSection: some View {
        if timerService.isCounting {
            Button("Take a Break Now") {
                timerService.takeBreakNow()
            }
            .keyboardShortcut("b", modifiers: [.command])

            Button("Skip Next Break") {
                timerService.skipNextBreak()
            }
        }

        if timerService.isOnBreak {
            Button("Skip Break") {
                timerService.skipCurrentBreak()
            }
        }

        if timerService.isPaused {
            Button("Resume") {
                timerService.resume()
            }
        }
    }

    // MARK: - About Panel

    private func showAboutPanel() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "Respite",
                .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
                .version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                .credits: NSAttributedString(
                    string: "A gentle reminder to take breaks.\nOpen source under MIT license.",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .foregroundColor: NSColor.secondaryLabelColor,
                    ]
                ),
            ]
        )
    }
}
