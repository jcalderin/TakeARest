import SwiftUI

/// The panel shown when clicking Respite's menubar icon.
///
/// Uses `.window` style MenuBarExtra — renders as a native SwiftUI panel,
/// not an NSMenu. This gives us partial view updates (no full rebuild
/// on every tick) and full design freedom for layout and animations.
struct MenuBarView: View {
    var timerService: TimerService

    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Countdown Display
            countdownSection
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.top, DesignTokens.spacingMD)
                .padding(.bottom, DesignTokens.spacingSM)

            Divider()

            // MARK: - Actions
            actionsSection
                .padding(.horizontal, DesignTokens.spacingXS)
                .padding(.vertical, DesignTokens.spacing2XS)

            Divider()

            // MARK: - Footer
            footerSection
                .padding(.horizontal, DesignTokens.spacingXS)
                .padding(.vertical, DesignTokens.spacing2XS)
        }
        .frame(width: 260)
    }

    // MARK: - Countdown Section

    @ViewBuilder
    private var countdownSection: some View {
        switch timerService.state {
        case .idle:
            VStack(spacing: DesignTokens.spacing2XS) {
                Text("Timer not started")
                    .respiteBody()
                    .foregroundStyle(.secondary)
            }

        case .counting:
            VStack(spacing: DesignTokens.spacing2XS) {
                Text("Next break in")
                    .respiteCaption()
                Text(timerService.countdownFormatted)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.3), value: timerService.secondsUntilBreak)
            }

        case .onBreak:
            VStack(spacing: DesignTokens.spacing2XS) {
                Text("Taking a break")
                    .respiteCaption()
                Text(timerService.countdownFormatted)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.primaryBlue)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.3), value: timerService.secondsRemainingInBreak)
            }

        case .paused(let until):
            VStack(spacing: DesignTokens.spacing2XS) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                if until != nil, let formatted = timerService.pauseRemainingFormatted {
                    Text("Paused — resumes in \(formatted)")
                        .respiteCaption()
                        .monospacedDigit()
                } else {
                    Text("Paused")
                        .respiteBody()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var actionsSection: some View {
        if timerService.isCounting {
            MenuPanelButton("Take a Break Now", systemImage: "cup.and.saucer") {
                timerService.takeBreakNow()
            }
            MenuPanelButton("Skip Next Break", systemImage: "forward.end") {
                timerService.skipNextBreak()
            }
        }

        if timerService.isOnBreak {
            MenuPanelButton("End Break", systemImage: "xmark.circle") {
                timerService.skipCurrentBreak()
            }
        }

        if timerService.isPaused {
            MenuPanelButton("Resume", systemImage: "play.fill") {
                timerService.resume()
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 0) {
            MenuPanelButton("Preferences...", systemImage: "gearshape") {
                openSettings()
                NSApplication.shared.activate(ignoringOtherApps: true)
                dismiss()
            }
            MenuPanelButton("Quit Respite", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Menu Panel Button

/// A button styled for the menubar panel — full-width, hover highlight,
/// icon + label layout matching macOS system menus.
private struct MenuPanelButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .foregroundStyle(isHovering ? .white : .secondary)
                Text(title)
                    .respiteBody()
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingXS)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color.accentColor : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
