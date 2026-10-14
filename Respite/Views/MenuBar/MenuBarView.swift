import SwiftUI

/// The panel shown when clicking Respite's menubar icon.
///
/// Shows all active timer countdowns with per-timer actions,
/// global pause/resume controls, and inactive timer overview.
/// Inactive timers shown in a collapsible section.
struct MenuBarView: View {
    var timerManager: TimerManager
    var settings: AppSettings

    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showingPauseOptions = false
    @State private var showInactive = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.primaryBlue)
                Text("Respite")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, DesignTokens.spacingXS)

            Divider()

            // MARK: - Active Timers
            if timerManager.activeEngines.isEmpty && timerManager.inactiveEngines.isEmpty {
                emptyState
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingLG)
            } else if timerManager.activeEngines.isEmpty {
                VStack(spacing: DesignTokens.spacing2XS) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text("No active timers")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingMD)
            } else {
                VStack(spacing: 1) {
                    ForEach(timerManager.activeEngines) { engine in
                        TimerRow(
                            engine: engine,
                            timerManager: timerManager,
                            settings: settings
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.spacingXS)
                .padding(.vertical, DesignTokens.spacingXS)
            }

            // MARK: - Inactive Timers (collapsible)
            if !timerManager.inactiveEngines.isEmpty {
                Divider()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInactive.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showInactive ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .frame(width: 10)
                        Text("Inactive (\(timerManager.inactiveEngines.count))")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignTokens.spacingSM)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)

                if showInactive {
                    VStack(spacing: 0) {
                        ForEach(timerManager.inactiveEngines) { engine in
                            HStack(spacing: DesignTokens.spacingXS) {
                                Circle()
                                    .fill(engine.breakTimer.overlayColor.opacity(0.4))
                                    .frame(width: 6, height: 6)
                                Text(engine.breakTimer.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                Spacer()
                                Text(engine.breakTimer.isEnabled ? "Outside hours" : "Disabled")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.quaternary)

                                // Enable / disable toggle
                                Toggle("", isOn: Binding(
                                    get: { engine.breakTimer.isEnabled },
                                    set: { _ in
                                        var updated = engine.breakTimer
                                        updated.isEnabled.toggle()
                                        settings.updateTimer(updated)
                                        timerManager.syncEngines()
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .tint(DesignTokens.primaryBlue)
                            }
                            .padding(.horizontal, DesignTokens.spacingSM)
                            .padding(.vertical, 3)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Divider()

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
                    .font(.system(size: 12))
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
/// Tapping expands to reveal per-timer action buttons.
private struct TimerRow: View {
    var engine: TimerEngine
    var timerManager: TimerManager
    var settings: AppSettings

    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Main Row
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignTokens.spacingXS) {
                    // Color indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(engine.breakTimer.overlayColor)
                        .frame(width: 4, height: 28)

                    // Name
                    VStack(alignment: .leading, spacing: 1) {
                        Text(engine.breakTimer.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        if engine.isPaused {
                            Text("Paused")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    // Countdown — fixed width to prevent shifting
                    statusView

                    // Expand indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(isExpanded ? -180 : 0))
                }
                .padding(.horizontal, DesignTokens.spacingXS)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSM)
                        .fill(isHovering ? Color.primary.opacity(0.04) : .clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .contextMenu { timerContextMenu }

            // MARK: - Expanded Actions
            if isExpanded {
                timerActions
                    .padding(.horizontal, DesignTokens.spacingSM)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Status (countdown)

    @ViewBuilder
    private var statusView: some View {
        switch engine.state {
        case .counting:
            Text(engine.countdownFormatted)
                .font(.system(size: 13, weight: .light, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
                .foregroundStyle(.primary)

        case .onBreak:
            HStack(spacing: 4) {
                Circle()
                    .fill(DesignTokens.primaryBlue)
                    .frame(width: 6, height: 6)
                Text(engine.countdownFormatted)
                    .font(.system(size: 13, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.primaryBlue)
            }
            .frame(minWidth: 52, alignment: .trailing)

        case .paused(let until):
            if until != nil, let formatted = engine.pauseRemainingFormatted {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8))
                    Text(formatted)
                        .font(.system(size: 13, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.orange)
                .frame(minWidth: 52, alignment: .trailing)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8))
                    Text("Paused")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.orange)
                .frame(minWidth: 52, alignment: .trailing)
            }

        case .idle:
            Text("Idle")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    // MARK: - Expanded Action Buttons

    @ViewBuilder
    private var timerActions: some View {
        HStack(spacing: 6) {
            if engine.isCounting {
                TimerActionButton("Skip Next", icon: "forward.end.fill") {
                    engine.skipNextBreak()
                }
                TimerActionButton("Break Now", icon: "play.fill") {
                    engine.takeBreakNow()
                }
                TimerActionButton("Pause", icon: "pause.fill") {
                    engine.pause(minutes: nil)
                }
            } else if engine.isPaused {
                TimerActionButton("Resume", icon: "play.fill") {
                    engine.resume()
                }
            } else if engine.isOnBreak {
                TimerActionButton("Skip", icon: "forward.end.fill") {
                    engine.skipCurrentBreak()
                }
                if engine.canPostpone {
                    TimerActionButton("+5 min", icon: "clock.arrow.circlepath") {
                        engine.postponeBreak(minutes: 5)
                    }
                }
            }

            Spacer()

            // Enable / disable — always visible
            TimerActionButton(
                engine.breakTimer.isEnabled ? "Disable" : "Enable",
                icon: engine.breakTimer.isEnabled ? "xmark.circle" : "checkmark.circle",
                tint: engine.breakTimer.isEnabled ? .secondary : DesignTokens.primaryBlue
            ) {
                toggleEnabled()
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var timerContextMenu: some View {
        if engine.isCounting {
            Button("Skip Next Break") { engine.skipNextBreak() }
            Button("Take a Break Now") { engine.takeBreakNow() }
            Divider()
            Button("Pause Indefinitely") { engine.pause(minutes: nil) }
        } else if engine.isPaused {
            Button("Resume") { engine.resume() }
        } else if engine.isOnBreak {
            Button("Skip This Break") { engine.skipCurrentBreak() }
            if engine.canPostpone {
                Button("Postpone 5 min") { engine.postponeBreak(minutes: 5) }
            }
        }
        Divider()
        Button(engine.breakTimer.isEnabled ? "Disable Timer" : "Enable Timer") {
            toggleEnabled()
        }
    }

    private func toggleEnabled() {
        var updated = engine.breakTimer
        updated.isEnabled.toggle()
        settings.updateTimer(updated)
        timerManager.syncEngines()
    }
}

// MARK: - Timer Action Button

/// A compact action button used inside expanded timer rows.
private struct TimerActionButton: View {
    let title: String
    let icon: String
    let tint: Color?
    let action: () -> Void

    @State private var isHovering = false

    init(
        _ title: String,
        icon: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(tint ?? .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color.primary.opacity(0.1) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
