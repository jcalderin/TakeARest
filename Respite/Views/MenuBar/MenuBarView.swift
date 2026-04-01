import SwiftUI

/// The panel shown when clicking Respite's menubar icon.
///
/// Shows all active timer countdowns, with actions per-timer and
/// global pause/resume controls. Inactive timers shown in a
/// collapsible section.
struct MenuBarView: View {
    var timerManager: TimerManager
    var settings: AppSettings

    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showingPauseOptions = false
    @State private var showInactive = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Active Timers
            if timerManager.activeEngines.isEmpty && timerManager.inactiveEngines.isEmpty {
                emptyState
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingLG)
            } else if timerManager.activeEngines.isEmpty {
                VStack(spacing: DesignTokens.spacing2XS) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No active timers")
                        .respiteCaption()
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
            } else {
                VStack(spacing: 0) {
                    ForEach(timerManager.activeEngines) { engine in
                        TimerRow(engine: engine)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingXS)
                .padding(.top, DesignTokens.spacingXS)
            }

            // MARK: - Inactive Timers (collapsible)
            if !timerManager.inactiveEngines.isEmpty {
                Divider()
                    .padding(.vertical, 2)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInactive.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: showInactive ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .frame(width: 12)
                        Text("Inactive (\(timerManager.inactiveEngines.count))")
                            .respiteCaption()
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignTokens.spacingSM)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if showInactive {
                    VStack(spacing: 0) {
                        ForEach(timerManager.inactiveEngines) { engine in
                            HStack(spacing: DesignTokens.spacingXS) {
                                Circle()
                                    .fill(engine.breakTimer.overlayColor.opacity(0.5))
                                    .frame(width: 8, height: 8)
                                Text(engine.breakTimer.name)
                                    .respiteCaption()
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text(engine.breakTimer.isEnabled ? "Outside schedule" : "Disabled")
                                    .font(.caption2)
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.horizontal, DesignTokens.spacingSM)
                            .padding(.vertical, 3)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Divider()
                .padding(.vertical, 2)

            // MARK: - Global Actions
            actionsSection
                .padding(.horizontal, DesignTokens.spacingXS)
                .padding(.vertical, DesignTokens.spacing2XS)

            Divider()

            // MARK: - Footer
            footerSection
                .padding(.horizontal, DesignTokens.spacingXS)
                .padding(.vertical, DesignTokens.spacing2XS)
        }
        .frame(width: 280)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No timers configured")
                .respiteBody()
                .foregroundStyle(.secondary)
            Text("Open Preferences to add your first break timer.")
                .respiteCaption()
                .multilineTextAlignment(.center)
            Button("Open Preferences") {
                openSettings()
                NSApplication.shared.activate(ignoringOtherApps: true)
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var actionsSection: some View {
        if timerManager.hasAnyCounting {
            if showingPauseOptions {
                pauseDurationOptions
            } else {
                MenuPanelButton("Pause All...", systemImage: "pause.circle") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingPauseOptions = true
                    }
                }
            }
        }

        if timerManager.hasAnyPaused {
            MenuPanelButton("Resume All", systemImage: "play.fill") {
                timerManager.resumeAll()
            }
        }
    }

    @ViewBuilder
    private var pauseDurationOptions: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "pause.circle")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text("Pause all for...")
                    .respiteCaption()
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingPauseOptions = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.spacingXS)
            .padding(.vertical, 4)

            MenuPanelButton("15 minutes", systemImage: "clock") {
                timerManager.pauseAll(minutes: 15)
                showingPauseOptions = false
            }
            MenuPanelButton("30 minutes", systemImage: "clock") {
                timerManager.pauseAll(minutes: 30)
                showingPauseOptions = false
            }
            MenuPanelButton("1 hour", systemImage: "clock") {
                timerManager.pauseAll(minutes: 60)
                showingPauseOptions = false
            }
            MenuPanelButton("2 hours", systemImage: "clock") {
                timerManager.pauseAll(minutes: 120)
                showingPauseOptions = false
            }
            MenuPanelButton("Until I Resume", systemImage: "infinity") {
                timerManager.pauseAll(minutes: nil)
                showingPauseOptions = false
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
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

// MARK: - Timer Row

/// A single timer's status row in the menubar panel.
private struct TimerRow: View {
    var engine: TimerEngine

    var body: some View {
        HStack(spacing: DesignTokens.spacingXS) {
            // Color indicator
            Circle()
                .fill(engine.breakTimer.overlayColor)
                .frame(width: 8, height: 8)

            // Name
            Text(engine.breakTimer.name)
                .respiteCaption()
                .lineLimit(1)

            Spacer()

            // Status
            statusView
        }
        .padding(.horizontal, DesignTokens.spacingXS)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var statusView: some View {
        switch engine.state {
        case .counting:
            Text(engine.countdownFormatted)
                .font(.system(size: 13, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.3), value: engine.secondsUntilBreak)

        case .onBreak:
            HStack(spacing: 4) {
                Text("Break")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.primaryBlue)
                Text(engine.countdownFormatted)
                    .font(.system(size: 13, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.primaryBlue)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.3), value: engine.secondsRemainingInBreak)
            }

        case .paused(let until):
            if until != nil, let formatted = engine.pauseRemainingFormatted {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                    Text(formatted)
                        .font(.system(size: 13, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                    Text("Paused")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

        case .idle:
            Text("Idle")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Menu Panel Button

/// A button styled for the menubar panel — full-width, hover highlight.
struct MenuPanelButton: View {
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
