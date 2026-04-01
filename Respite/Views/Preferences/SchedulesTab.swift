import SwiftUI

/// Schedules preferences tab — manage break schedules for different days/times.
struct SchedulesTab: View {
    @Bindable var settings: AppSettings
    @State private var selectedScheduleID: UUID?
    @State private var editingSchedule: BreakSchedule?

    var body: some View {
        Form {
            // MARK: - Enable/Disable
            Section {
                Toggle("Use custom schedules", isOn: $settings.useSchedules)

                if !settings.useSchedules {
                    Text("When disabled, the global break timing from the General tab is used.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if settings.useSchedules {
                // MARK: - Schedule List
                Section {
                    if settings.schedules.isEmpty {
                        VStack(spacing: DesignTokens.spacingSM) {
                            Text("No schedules yet")
                                .foregroundStyle(.secondary)
                            Text("Add a schedule to set different break intervals for weekdays, weekends, or custom time ranges.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingMD)
                    } else {
                        ForEach(settings.schedules) { schedule in
                            ScheduleRow(
                                schedule: schedule,
                                onEdit: { editingSchedule = schedule },
                                onToggle: { toggleSchedule(schedule) }
                            )
                        }
                        .onDelete { indexSet in
                            settings.schedules.remove(atOffsets: indexSet)
                        }
                    }
                } header: {
                    HStack {
                        Text("Schedules")
                        Spacer()
                        Button(action: addSchedule) {
                            Label("Add", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DesignTokens.primaryBlue)
                    }
                }

                // MARK: - Quick Add
                Section {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Button("Add Weekday") {
                            settings.schedules.append(.weekday())
                        }
                        .buttonStyle(.bordered)

                        Button("Add Weekend") {
                            settings.schedules.append(.weekend())
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("Quick Add")
                }

                // MARK: - Fallback Info
                Section {
                    Text("When no schedule matches the current time, the global settings from the General tab are used as a fallback.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } header: {
                    Text("Fallback")
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditor(schedule: schedule) { updated in
                if let index = settings.schedules.firstIndex(where: { $0.id == updated.id }) {
                    settings.schedules[index] = updated
                }
                editingSchedule = nil
            }
        }
    }

    private func addSchedule() {
        let schedule = BreakSchedule(
            id: UUID(),
            name: "New Schedule",
            activeDays: [2, 3, 4, 5, 6],
            breakIntervalMinutes: 20,
            breakDurationSeconds: 20,
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            isEnabled: true
        )
        settings.schedules.append(schedule)
        editingSchedule = schedule
    }

    private func toggleSchedule(_ schedule: BreakSchedule) {
        if let index = settings.schedules.firstIndex(where: { $0.id == schedule.id }) {
            settings.schedules[index].isEnabled.toggle()
        }
    }
}

// MARK: - Schedule Row

private struct ScheduleRow: View {
    let schedule: BreakSchedule
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingXS) {
                    Text(schedule.name)
                        .fontWeight(.medium)

                    if !schedule.isEnabled {
                        Text("Disabled")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }

                HStack(spacing: DesignTokens.spacingXS) {
                    Text(schedule.daysDescription)
                    Text("·")
                    Text(schedule.timeRangeDescription)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text("Every \(schedule.breakIntervalMinutes)m, \(schedule.breakDurationSeconds)s break")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Schedule Editor

private struct ScheduleEditor: View {
    @State var schedule: BreakSchedule
    var onSave: (BreakSchedule) -> Void

    @Environment(\.dismiss) private var dismiss

    private let weekdays = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"),
        (6, "Fri"), (7, "Sat"), (1, "Sun"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Schedule")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    onSave(schedule)
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()

            Divider()

            Form {
                // Name
                Section {
                    TextField("Name", text: $schedule.name)
                }

                // Days
                Section("Active Days") {
                    HStack(spacing: DesignTokens.spacingXS) {
                        ForEach(weekdays, id: \.0) { day, label in
                            DayToggle(
                                label: label,
                                isActive: schedule.activeDays.contains(day),
                                onToggle: { toggleDay(day) }
                            )
                        }
                    }
                }

                // Time Range
                Section("Active Hours") {
                    HStack {
                        Text("Start")
                        Spacer()
                        TimePicker(hour: $schedule.startHour, minute: $schedule.startMinute)
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        TimePicker(hour: $schedule.endHour, minute: $schedule.endMinute)
                    }
                }

                // Break Timing
                Section("Break Timing") {
                    HStack {
                        Text("Interval")
                        Spacer()
                        Stepper(
                            "\(schedule.breakIntervalMinutes) min",
                            value: $schedule.breakIntervalMinutes,
                            in: DesignTokens.minBreakIntervalMinutes...DesignTokens.maxBreakIntervalMinutes,
                            step: 5
                        )
                    }
                    HStack {
                        Text("Duration")
                        Spacer()
                        Stepper(
                            "\(schedule.breakDurationSeconds) sec",
                            value: $schedule.breakDurationSeconds,
                            in: DesignTokens.minBreakDurationSeconds...DesignTokens.maxBreakDurationSeconds,
                            step: 10
                        )
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 480)
    }

    private func toggleDay(_ day: Int) {
        if schedule.activeDays.contains(day) {
            schedule.activeDays.remove(day)
        } else {
            schedule.activeDays.insert(day)
        }
    }
}

// MARK: - Day Toggle Button

private struct DayToggle: View {
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

private struct TimePicker: View {
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
