import SwiftUI

/// Timers preferences tab — list/detail CRUD for all break timers.
///
/// Left column: list of timers with name, status indicator, summary.
/// Editing: sheet-based editor with full timer configuration.
struct TimersTab: View {
    @Bindable var settings: AppSettings
    var timerManager: TimerManager

    @State private var selectedTimerID: UUID?
    @State private var editingTimer: BreakTimer?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Timer List
            if settings.timers.isEmpty {
                emptyState
            } else {
                List(selection: $selectedTimerID) {
                    ForEach(settings.timers) { timer in
                        TimerListRow(timer: timer, engine: timerManager.engines[timer.id])
                            .tag(timer.id)
                            .contextMenu {
                                Button("Edit...") { editingTimer = timer }
                                Button("Duplicate") { duplicateTimer(timer) }
                                Divider()
                                Button(timer.isEnabled ? "Disable" : "Enable") {
                                    toggleTimer(timer)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    settings.removeTimer(id: timer.id)
                                    timerManager.syncEngines()
                                }
                            }
                            .onTapGesture(count: 2) { editingTimer = timer }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            settings.removeTimer(id: settings.timers[index].id)
                        }
                        timerManager.syncEngines()
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            Divider()

            // MARK: - Toolbar
            HStack(spacing: DesignTokens.spacingXS) {
                Button(action: addTimer) {
                    Image(systemName: "plus")
                }
                .help("Add a new timer")

                Button {
                    if let id = selectedTimerID,
                       let timer = settings.timers.first(where: { $0.id == id }) {
                        settings.removeTimer(id: id)
                        timerManager.syncEngines()
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedTimerID == nil)
                .help("Remove selected timer")

                Divider()
                    .frame(height: 16)

                Menu {
                    Button("Screen Break (20 min)") {
                        addPreset(.screenBreak())
                    }
                    Button("Stand Up & Walk (60 min)") {
                        addPreset(.standUpAndWalk())
                    }
                } label: {
                    Image(systemName: "wand.and.stars")
                }
                .help("Add from preset")

                Spacer()

                if let id = selectedTimerID,
                   settings.timers.first(where: { $0.id == id }) != nil {
                    Button("Edit") {
                        editingTimer = settings.timers.first { $0.id == id }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, DesignTokens.spacingXS)
        }
        .sheet(item: $editingTimer) { timer in
            TimerEditor(timer: timer) { updated in
                settings.updateTimer(updated)
                timerManager.syncEngines()
                editingTimer = nil
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Spacer()
            Image(systemName: "timer")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No break timers yet")
                .respiteTitle()
            Text("Create timers for different break types — screen breaks, stand up reminders, stretch breaks — each with their own schedule and appearance.")
                .respiteBody()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            HStack(spacing: DesignTokens.spacingSM) {
                Button("Add Screen Break") { addPreset(.screenBreak()) }
                    .buttonStyle(.bordered)
                Button("Add Stand Up Timer") { addPreset(.standUpAndWalk()) }
                    .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func addTimer() {
        let timer = BreakTimer(
            id: UUID(),
            name: "New Timer",
            isEnabled: true,
            breakIntervalMinutes: 20,
            breakDurationSeconds: 20,
            overlayColorHex: "#000000",
            overlayOpacity: 0.85,
            breakMessage: "Time for a break",
            dimAnimationDuration: 5.0,
            showCountdown: true,
            playSoundOnBreak: false,
            activeDays: [2, 3, 4, 5, 6],
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0
        )
        settings.addTimer(timer)
        timerManager.syncEngines()
        editingTimer = timer
    }

    private func addPreset(_ timer: BreakTimer) {
        settings.addTimer(timer)
        timerManager.syncEngines()
    }

    private func duplicateTimer(_ timer: BreakTimer) {
        var copy = timer
        copy.id = UUID()
        copy.name = "\(timer.name) Copy"
        settings.addTimer(copy)
        timerManager.syncEngines()
    }

    private func toggleTimer(_ timer: BreakTimer) {
        var updated = timer
        updated.isEnabled.toggle()
        settings.updateTimer(updated)
        timerManager.syncEngines()
    }
}

// MARK: - Timer List Row

private struct TimerListRow: View {
    let timer: BreakTimer
    let engine: TimerEngine?

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Color swatch
            RoundedRectangle(cornerRadius: 4)
                .fill(timer.overlayColor)
                .frame(width: 6, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingXS) {
                    Text(timer.name)
                        .fontWeight(.medium)

                    if !timer.isEnabled {
                        Text("Disabled")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }

                Text("Every \(timer.intervalFormatted), \(timer.durationFormatted) break")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(timer.daysDescription)
                    Text("·")
                    Text(timer.timeRangeDescription)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Live status from engine
            if let engine {
                engineStatusBadge(engine)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func engineStatusBadge(_ engine: TimerEngine) -> some View {
        if engine.isCounting {
            Text(engine.countdownFormatted)
                .font(.system(size: 12, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else if engine.isOnBreak {
            Text("On Break")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignTokens.primaryBlue, in: Capsule())
        } else if engine.isPaused {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Timer Editor

struct TimerEditor: View {
    @State var timer: BreakTimer
    var onSave: (BreakTimer) -> Void

    @Environment(\.dismiss) private var dismiss

    private let weekdays = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"),
        (6, "Fri"), (7, "Sat"), (1, "Sun"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Timer")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(timer) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                // MARK: - Identity
                Section("Name") {
                    TextField("Timer name", text: $timer.name)

                    Toggle("Enabled", isOn: $timer.isEnabled)
                }

                // MARK: - Timing
                Section("Break Timing") {
                    HStack {
                        Text("Break every")
                        Spacer()
                        Stepper(
                            "\(timer.breakIntervalMinutes) min",
                            value: $timer.breakIntervalMinutes,
                            in: DesignTokens.minBreakIntervalMinutes...DesignTokens.maxBreakIntervalMinutes,
                            step: 5
                        )
                    }
                    HStack {
                        Text("Break lasts")
                        Spacer()
                        Stepper(
                            "\(timer.breakDurationSeconds) sec",
                            value: $timer.breakDurationSeconds,
                            in: DesignTokens.minBreakDurationSeconds...DesignTokens.maxBreakDurationSeconds,
                            step: 10
                        )
                    }
                }

                // MARK: - Schedule
                Section("Schedule") {
                    HStack(spacing: DesignTokens.spacingXS) {
                        ForEach(weekdays, id: \.0) { day, label in
                            DayToggle(
                                label: label,
                                isActive: timer.activeDays.contains(day),
                                onToggle: { toggleDay(day) }
                            )
                        }
                    }

                    HStack {
                        Text("Start")
                        Spacer()
                        TimePicker(hour: $timer.startHour, minute: $timer.startMinute)
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        TimePicker(hour: $timer.endHour, minute: $timer.endMinute)
                    }
                }

                // MARK: - Appearance
                Section("Appearance") {
                    HStack {
                        Text("Overlay Color")
                        Spacer()
                        ColorPicker(
                            "",
                            selection: Binding(
                                get: { timer.overlayColor },
                                set: { timer.overlayColorHex = $0.toHex() ?? "#000000" }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }

                    HStack {
                        Text("Opacity")
                        Spacer()
                        Text("\(Int(timer.overlayOpacity * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $timer.overlayOpacity,
                        in: DesignTokens.overlayMinOpacity...DesignTokens.overlayMaxOpacity,
                        step: 0.05
                    )

                    TextField("Break message", text: $timer.breakMessage)

                    HStack {
                        Text("Fade-in")
                        Spacer()
                        Text(String(format: "%.1fs", timer.dimAnimationDuration))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $timer.dimAnimationDuration,
                        in: 1.0...DesignTokens.overlayDimDurationMax,
                        step: 0.5
                    )
                }

                // MARK: - Behavior
                Section("Behavior") {
                    Toggle("Show countdown during break", isOn: $timer.showCountdown)
                    Toggle("Play sound when break starts", isOn: $timer.playSoundOnBreak)
                }

                // MARK: - Preview
                Section("Preview") {
                    TimerOverlayPreview(timer: timer)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSM))
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 640)
    }

    private func toggleDay(_ day: Int) {
        if timer.activeDays.contains(day) {
            timer.activeDays.remove(day)
        } else {
            timer.activeDays.insert(day)
        }
    }
}

// MARK: - Day Toggle Button

struct DayToggle: View {
    let label: String
    let isActive: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(label)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .frame(width: 36, height: 28)
                .background(
                    isActive ? DesignTokens.primaryBlue.opacity(0.2) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? DesignTokens.primaryBlue : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? DesignTokens.primaryBlue : .secondary)
    }
}

// MARK: - Time Picker

struct TimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 2) {
            Picker("", selection: $hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .labelsHidden()
            .frame(width: 60)

            Text(":")
                .foregroundStyle(.secondary)

            Picker("", selection: $minute) {
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: 60)
        }
    }
}

// MARK: - Timer Overlay Preview

private struct TimerOverlayPreview: View {
    var timer: BreakTimer

    var body: some View {
        ZStack {
            timer.overlayColor
                .opacity(timer.overlayOpacity)

            VStack(spacing: DesignTokens.spacingXS) {
                Text(timer.breakMessage)
                    .font(.system(size: 14, weight: .light, design: .rounded))
                    .foregroundStyle(.white)

                if timer.showCountdown {
                    Text("14:32")
                        .font(.system(size: 24, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}
