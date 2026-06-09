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
                            Button("Test") { timerManager.runTest(for: timer.id) }
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
            TimerEditor(
                timer: timer,
                allTimers: settings.timers,
                onTest: { edited in
                    // Apply the in-progress config so the test reflects it, then preview.
                    settings.updateTimer(edited)
                    timerManager.syncEngines()
                    timerManager.runTest(for: edited.id)
                },
                onSave: { updated in
                    settings.updateTimer(updated)
                    timerManager.syncEngines()
                    editingTimer = nil
                }
            )
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

                    HStack(spacing: 4) {
                        Text("\(timer.cadenceDescription), \(timer.durationFormatted) break")
                            .foregroundStyle(.secondary)
                        if !timer.coveredByTimerIDs.isEmpty {
                            Image(systemName: "rectangle.on.rectangle.slash")
                                .foregroundStyle(.tertiary)
                                .help("Covered by \(timer.coveredByTimerIDs.count) timer(s) — skips coincident breaks")
                        }
                    }
                    .font(.caption)
                    .help("Fires \(timer.firingPreview)")

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
    @State private var timer: BreakTimer
    /// Which unit the "How often" control is showing. Derived from the timer's
    /// interval on open; not persisted (firing is the same either way).
    @State private var repeatUnit: RepeatUnit
    /// Remembered values per unit, so switching units round-trips without losing
    /// the user's number.
    @State private var lastMinutes: Int
    @State private var lastHours: Int
    /// All timers, used to populate the "Covered by" picker. Excludes self.
    let allTimers: [BreakTimer]
    var onTest: (BreakTimer) -> Void = { _ in }
    let onSave: (BreakTimer) -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        timer: BreakTimer,
        allTimers: [BreakTimer] = [],
        onTest: @escaping (BreakTimer) -> Void = { _ in },
        onSave: @escaping (BreakTimer) -> Void
    ) {
        _timer = State(initialValue: timer)
        let hourly = timer.isHourly
        _repeatUnit = State(initialValue: hourly ? .hours : .minutes)
        _lastMinutes = State(initialValue: hourly ? 20 : timer.breakIntervalMinutes)
        _lastHours = State(initialValue: hourly ? timer.breakIntervalMinutes / 60 : 1)
        self.allTimers = allTimers
        self.onTest = onTest
        self.onSave = onSave
    }

    enum RepeatUnit { case minutes, hours }

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
                Button("Test") { onTest(timer) }
                    .help("Preview the heads-up and break for this timer")
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
                    preWarnSection
                    scheduleSection
                    coordinationSection
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

    // MARK: - How Often Section

    private var timingSection: some View {
        GlassSection("How Often") {
            SettingRow {
                Text("Repeat")
                Spacer()
                Picker("", selection: Binding(
                    get: { repeatUnit },
                    set: { setUnit($0) }
                )) {
                    Text("Minutes").tag(RepeatUnit.minutes)
                    Text("Hours").tag(RepeatUnit.hours)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }

            GlassDivider()

            if repeatUnit == .minutes {
                SettingRow {
                    Text("Every")
                    Spacer()
                    CompactNumberInput(
                        value: $timer.breakIntervalMinutes,
                        range: 5...55,
                        step: 5,
                        unit: "min"
                    )
                }
                GlassDivider()
                SettingRow {
                    Text("At minute")
                    Spacer()
                    CompactNumberInput(value: $timer.alignMinute, range: 0...59, step: 1, unit: "min")
                }
            } else {
                SettingRow {
                    Text("Every")
                    Spacer()
                    CompactNumberInput(value: hoursBinding, range: 1...12, step: 1, unit: "hr")
                }
                GlassDivider()
                SettingRow {
                    Text("At minute")
                    Spacer()
                    CompactNumberInput(value: $timer.alignMinute, range: 0...59, step: 1, unit: "min")
                }
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

            SectionCaption("Fires \(timer.firingPreview).")
        }
        .transition(.opacity)
    }

    /// Hours view over the minute-based interval.
    private var hoursBinding: Binding<Int> {
        Binding(
            get: { max(1, timer.breakIntervalMinutes / 60) },
            set: { timer.breakIntervalMinutes = $0 * 60 }
        )
    }

    /// Switch units, remembering the outgoing value and restoring the other
    /// unit's last value so the user's number isn't lost.
    private func setUnit(_ unit: RepeatUnit) {
        guard unit != repeatUnit else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if unit == .hours {
                lastMinutes = timer.breakIntervalMinutes
                timer.breakIntervalMinutes = lastHours * 60
            } else {
                lastHours = max(1, timer.breakIntervalMinutes / 60)
                timer.breakIntervalMinutes = lastMinutes
            }
            repeatUnit = unit
        }
    }

    // MARK: - Heads-Up Section

    private var preWarnSection: some View {
        GlassSection("Heads-Up") {
            SettingRow {
                Text("Warn before break")
                Spacer()
                Picker("", selection: Binding(
                    get: { timer.preWarnStyle },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.2)) { timer.preWarnStyle = newValue }
                    }
                )) {
                    ForEach(PreWarnStyle.allCases, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            if timer.preWarnStyle != .off {
                GlassDivider()
                SettingRow {
                    Text("Lead time")
                    Spacer()
                    CompactNumberInput(
                        value: $timer.preWarnSeconds,
                        range: DesignTokens.minPreWarnSeconds...DesignTokens.maxPreWarnSeconds,
                        step: 5,
                        unit: "sec"
                    )
                }
                SectionCaption("A heads-up appears \(timer.preWarnSeconds)s before the break so you can wrap up. It never steals focus.")
            }
        }
        .transition(.opacity)
    }

    // MARK: - Coordination Section

    private var coordinationSection: some View {
        let candidates = allTimers.filter { $0.id != timer.id }

        return GlassSection("Coordination") {
            SettingRow {
                Text("Covered by")
                Spacer()
                CoverageMenu(
                    selection: $timer.coveredByTimerIDs,
                    candidates: candidates
                )
            }

            SectionCaption("When a covering timer's break runs, this timer skips its coincident break that one time.")
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

/// A one-line hint beneath a section's rows, left-aligned to the row labels.
private struct SectionCaption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack {
            Text(text)
                .respiteCaption()
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.bottom, 8)
    }
}

/// Popup menu for choosing which other timers cover this one. The trigger
/// summarizes the selection; each item toggles membership with a checkmark.
private struct CoverageMenu: View {
    @Binding var selection: Set<UUID>
    let candidates: [BreakTimer]

    var body: some View {
        if candidates.isEmpty {
            Text("No other timers")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .help("Add another timer to use coverage.")
        } else {
            Menu {
                ForEach(candidates) { candidate in
                    Toggle(candidate.name, isOn: Binding(
                        get: { selection.contains(candidate.id) },
                        set: { isOn in
                            if isOn { selection.insert(candidate.id) }
                            else { selection.remove(candidate.id) }
                        }
                    ))
                }
            } label: {
                Text(summaryLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(selection.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 200, alignment: .trailing)
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "None" / single name / "Name +N" — kept to one line within the trigger.
    private var summaryLabel: String {
        let names = candidates.filter { selection.contains($0.id) }.map(\.name)
        switch names.count {
        case 0: return "None"
        case 1: return names[0]
        default: return "\(names[0]) +\(names.count - 1)"
        }
    }
}

// MARK: - Compact Number Input

private extension View {
    /// Shared styling for the compact inline text fields in this tab.
    func compactInputField(width: CGFloat, hPadding: CGFloat = 5) -> some View {
        self
            .textFieldStyle(.plain)
            .frame(width: width)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, hPadding)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

/// A compact inline unit label ("%", "s", "min", …).
private struct UnitLabel: View {
    let text: String
    var width: CGFloat?

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
    }
}

/// TextField + Stepper in a compact inline layout, vertically centered.
private struct CompactNumberInput: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, format: .number)
                .compactInputField(width: 38, hPadding: 6)

            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()

            UnitLabel(text: unit, width: 26)
        }
    }
}

/// A compact percent input (integer) for opacity.
private struct CompactPercentInput: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 3) {
            TextField("", value: $value, format: .number)
                .compactInputField(width: 30)
            UnitLabel(text: "%")
        }
    }
}

/// A compact seconds input (one decimal) for fade-in duration.
private struct CompactSecondsInput: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 3) {
            TextField("", value: $value, format: .number.precision(.fractionLength(1)))
                .compactInputField(width: 34)
            UnitLabel(text: "s")
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
