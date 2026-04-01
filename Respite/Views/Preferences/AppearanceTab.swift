import SwiftUI

/// Appearance preferences tab — overlay color, opacity, message, animation.
struct AppearanceTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            // MARK: - Overlay Background
            Section {
                HStack {
                    Text("Background Color")
                    Spacer()
                    ColorPicker("", selection: $settings.overlayColor, supportsOpacity: false)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    HStack {
                        Text("Opacity")
                        Spacer()
                        Text("\(Int(settings.overlayOpacity * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settings.overlayOpacity,
                        in: DesignTokens.overlayMinOpacity...DesignTokens.overlayMaxOpacity,
                        step: 0.05
                    )
                }
            } header: {
                Text("Overlay Background")
            }

            // MARK: - Message
            Section {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    TextField("Break message", text: $settings.breakMessage)
                        .textFieldStyle(.roundedBorder)

                    Text("Shown on the overlay during breaks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Button("Reset to Default") {
                    settings.breakMessage = DesignTokens.defaultBreakMessage
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.primaryBlue)
                .font(.caption)
            } header: {
                Text("Break Message")
            }

            // MARK: - Animation
            Section {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    HStack {
                        Text("Fade-in Duration")
                        Spacer()
                        Text(String(format: "%.1fs", settings.dimAnimationDuration))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settings.dimAnimationDuration,
                        in: 1.0...DesignTokens.overlayDimDurationMax,
                        step: 0.5
                    )

                    Text("How quickly the overlay fades in — slower feels calmer")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Animation")
            }

            // MARK: - Preview
            Section {
                OverlayPreview(settings: settings)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSM))
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Overlay Preview

/// A miniature preview of the overlay appearance with current settings.
private struct OverlayPreview: View {
    var settings: AppSettings

    var body: some View {
        ZStack {
            settings.overlayColor
                .opacity(settings.overlayOpacity)

            VStack(spacing: DesignTokens.spacingSM) {
                Text(settings.breakMessage)
                    .font(.system(size: 16, weight: .light, design: .rounded))
                    .foregroundStyle(.white)

                if settings.showCountdown {
                    Text("14:32")
                        .font(.system(size: 28, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}
