import SwiftUI

/// The dropdown menu shown when clicking Respite's menubar icon.
///
/// Phase 2: Basic menu with About and Quit.
/// Future phases will add timer status, pause controls, and preferences.
struct MenuBarView: View {
    var body: some View {
        Button("About Respite") {
            showAboutPanel()
        }
        .keyboardShortcut("i", modifiers: [.command])

        Divider()

        Button("Quit Respite") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }

    private func showAboutPanel() {
        // Activate the app so the about panel appears in front,
        // even though we're an LSUIElement (agent) app with no Dock icon.
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
