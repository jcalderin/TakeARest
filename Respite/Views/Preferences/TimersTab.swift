import SwiftUI

/// Timers preferences tab — list/detail CRUD for all break timers.
///
/// Left column: list of timers with name, status, enable toggle, summary.
/// Editing: sheet-based editor with modern glass-card sections.
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
                        TimerListRow(
                            timer: timer,
                            engine: timerManager.engines[timer.id],
                            onToggle: { toggleTimer(timer) },
                            onEdit: { editingTimer = timer }
                        )
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
                       settings.timers.contains(where: { $0.id == id }) {
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
                   settings.timers.contains(where: { $0.id == id }) {
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
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Content area — double-click opens editor
            HStack(spacing: DesignTokens.spacingSM) {
                // Color swatch
                RoundedRectangle(cornerRadius: 4)
                    .fill(timer.isEnabled ? timer.overlayColor : timer.overlayColor.opacity(0.3))
                    .frame(width: 6, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.name)
                        .fontWeight(.medium)
                        .foregroundStyle(timer.isEnabled ? .primary : .secondary)

                    Text("Every \(timer.intervalFormatted), \(timer.durationFormatted) break")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(timer.daysDescription)
                        Text("\u{00B7}")
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
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onEdit() }

            // Enable / disable toggle — outside double-click area
            Toggle("", isOn: Binding(
                get: { timer.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(DesignTokens.primaryBlue)
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
                .frame(minWidth: 44, alignment: .trailing)
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

// MARK: - Timer Editor (Modern Glass Design)

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
            // MARK: - Header
            HStack {
                Text("Edit Timer")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(timer) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.primaryBlue)
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)

            Divider()

            // MARK: - Content
            ScrollView {
                VStack(spacing: DesignTokens.spacingSM) {
                    nameSection
                    timingSection
                    scheduleSection
                    appearanceSection
                    behaviorSection
                    previewSection
                }
                .padding(DesignTokens.spacingMD)
            }
        }
        .frame(width: 540, height: 720)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        GlassSection("Name") {
            SettingRow {
                Text("Name")
                Spacer()
                TextField("Timer name", text: $timer.name)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
            }

            GlassDivider()

            SettingRow {
                Toggle("Enabled", isOn: $timer.isEnabled)
                    .tint(DesignTokens.primaryBlue)
            }
        }
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        GlassSection("Break Timing") {
            SettingRow {
                Text("Break every")
                Spacer()
                CompactNumberInput(
                    value: $timer.breakIntervalMinutes,
                    range: DesignTokens.minBreakIntervalMinutes...DesignTokens.maxBreakIntervalMinutes,
                    step: 5,
                    unit: "min"
                )
            }

            GlassDivider()

            SettingRow {
                Text("Break lasts")
                Spacer()
                CompactNumberInput(
                    value: $timer.breakDurationSeconds,
                    range: DesignTokens.minBreakDurationSeconds...DesignTokens.maxBreakDurationSeconds,
                    step: 10,
                    unit: "sec"
                )
            }
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        GlassSection("Schedule") {
            SettingRow {
                HStack(spacing: DesignTokens.spacingXS) {
                    ForEach(weekdays, id: \.0) { day, label in
                        DayToggle(
                            label: label,
                            isActive: timer.activeDays.contains(day),
                            onToggle: { toggleDay(day) }
                        )
                    }
                }
            }

            GlassDivider()

            SettingRow {
                Text("Start")
                Spacer()
                TimePicker(hour: $timer.startHour, minute: $timer.startMinute)
            }

            GlassDivider()

            SettingRow {
                Text("End")
                Spacer()
                TimePicker(hour: $timer.endHour, minute: $timer.endMinute)
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        GlassSection("Appearance") {
            SettingRow {
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

            GlassDivider()

            SettingRow {
                Text("Opacity")
                Spacer(minLength: DesignTokens.spacingSM)
                Slider(
                    value: $timer.overlayOpacity,
                    in: DesignTokens.overlayMinOpacity...DesignTokens.overlayMaxOpacity,
                    step: 0.05
                )
                .frame(maxWidth: 140)
                CompactPercentInput(
                    value: Binding(
                        get: { Int(timer.overlayOpacity * 100) },
                        set: {
                            timer.overlayOpacity = (Double($0) / 100.0)
                                .clamped(to: DesignTokens.overlayMinOpacity...DesignTokens.overlayMaxOpacity)
                        }
                    )
                )
            }

            GlassDivider()

            SettingRow {
                Text("Message")
                Spacer()
                TextField("Break message", text: $timer.breakMessage)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
            }

            GlassDivider()

            SettingRow {
                Text("Fade-in")
                Spacer(minLength: DesignTokens.spacingSM)
                Slider(
                    value: $timer.dimAnimationDuration,
                    in: 1.0...DesignTokens.overlayDimDurationMax,
                    step: 0.5
                )
                .frame(maxWidth: 140)
                CompactSecondsInput(value: $timer.dimAnimationDuration)
            }
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        GlassSection("Behavior") {
            SettingRow {
                Toggle("Show countdown during break", isOn: $timer.showCountdown)
                    .tint(DesignTokens.primaryBlue)
            }

            GlassDivider()

            SettingRow {
                Toggle("Play sound when break starts", isOn: $timer.playSoundOnBreak)
                    .tint(DesignTokens.primaryBlue)
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        GlassSection("Preview") {
            TimerOverlayPreview(timer: timer)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Helpers

    private func toggleDay(_ day: Int) {
        if timer.activeDays.contains(day) {
            timer.activeDays.remove(day)
        } else {
            timer.activeDays.insert(day)
        }
    }
}

// MARK: - Glass Section Card

/// A translucent glass-material section card for the modern editor layout.
private struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
        }
    }
}

/// A single row inside a glass section.
private struct SettingRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            content
        }
        .font(.system(size: 13))
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.vertical, 8)
    }
}

/// An iOS-style inset divider for glass sections.
private struct GlassDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, DesignTokens.spacingSM)
    }
}

// MARK: - Compact Number Input

/// TextField + Stepper in a compact inline layout, vertically centered.
private struct CompactNumberInput: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, format: .number)
                .textFieldStyle(.plain)
                .frame(width: 38)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )

            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()

            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
        }
    }
}

/// A compact percent input (integer) for opacity.
private struct CompactPercentInput: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 3) {
            TextField("", value: $value, format: .number)
                .textFieldStyle(.plain)
                .frame(width: 30)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            Text("%")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

/// A compact seconds input (one decimal) for fade-in duration.
private struct CompactSecondsInput: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 3) {
            TextField("", value: $value, format: .number.precision(.fractionLength(1)))
                .textFieldStyle(.plain)
                .frame(width: 34)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            Text("s")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
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
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .frame(width: 36, height: 26)
                .background(
                    isActive
                        ? DesignTokens.primaryBlue.opacity(0.15)
                        : Color.primary.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isActive
                                ? DesignTokens.primaryBlue.opacity(0.4)
                                : Color.primary.opacity(0.08),
                            lineWidth: 0.5
                        )
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
                ForEach(0..<60, id: \.self) { m in
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
