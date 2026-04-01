import SwiftUI

/// The dropdown menu shown when clicking Respite's menubar icon.
///
/// IMPORTANT: This uses `.menu` style MenuBarExtra, which renders as a native
/// NSMenu. Every @Observable property accessed in `body` triggers a full
/// menu rebuild. To avoid per-second jitter, we only access stable properties
/// (`state`, `nextBreakDate`) during counting — NOT `secondsUntilBreak`.
struct MenuBarView: View {
    var timerService: TimerService

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // MARK: - Timer Status (stable — only changes on state transitions)
        statusText

        Divider()

        // MARK: - Timer Controls (always present, disabled when irrelevant)
        Button("Take a Break Now") {
            timerService.takeBreakNow()
        }
        .disabled(!timerService.isCounting)
        .keyboardShortcut("b", modifiers: [.command])

        Button("Skip Next Break") {
            timerService.skipNextBreak()
        }
        .disabled(!timerService.isCounting)

        Button("End Break") {
            timerService.skipCurrentBreak()
        }
        .disabled(!timerService.isOnBreak)

        Button("Resume") {
            timerService.resume()
        }
        .disabled(!timerService.isPaused)

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

    // MARK: - Status Text

    /// Computed from stable properties only — avoids per-second menu rebuilds.
    /// `nextBreakDate` only changes on start/skip/break events, not every tick.
    /// `state` only changes on transitions (idle→counting→onBreak→paused).
    private var statusText: Text {
        switch timerService.state {
        case .idle:
            return Text("Timer not started")

        case .counting:
            // Compute minutes from the stable nextBreakDate, not from
            // the per-second secondsUntilBreak counter.
            if let breakDate = timerService.nextBreakDate {
                let remaining = max(0, Int(breakDate.timeIntervalSinceNow))
                if remaining < 60 {
                    return Text("Break in less than a minute")
                } else {
                    let minutes = remaining / 60
                    return Text("Next break in \(minutes) min")
                }
            } else {
                return Text("Respite is running")
            }

        case .onBreak:
            // During breaks (short, ~20s) we accept the per-second rebuild
            // since the overlay covers the screen and this menu is rarely visible.
            return Text("On break — \(timerService.countdownFormatted) left")

        case .paused(let until):
            if until != nil, let formatted = timerService.pauseRemainingFormatted {
                return Text("Paused — resumes in \(formatted)")
            } else {
                return Text("Paused")
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
