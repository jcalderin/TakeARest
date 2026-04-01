import SwiftUI

/// The full-screen break overlay content.
///
/// Shown inside the overlay NSWindow. Displays a calming background,
/// a break message, a countdown, and dismiss/postpone controls.
struct OverlayView: View {
    var timerService: TimerService
    var settings: AppSettings
    var onSkip: () -> Void
    var onPostpone: () -> Void

    var body: some View {
        ZStack {
            // MARK: - Background
            Color.black
                .opacity(settings.dimAnimationDuration > 0 ? DesignTokens.overlayDefaultOpacity : 1)
                .ignoresSafeArea()

            // MARK: - Content
            VStack(spacing: DesignTokens.spacingXL) {
                Spacer()

                // Break message
                Text(DesignTokens.defaultBreakMessage)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .foregroundStyle(.white)

                // Countdown
                if settings.showCountdown {
                    Text(timerService.countdownFormatted)
                        .respiteHero()
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.3), value: timerService.secondsRemainingInBreak)
                }

                // Progress bar
                BreakProgressBar(
                    elapsed: settings.breakDurationSeconds - timerService.secondsRemainingInBreak,
                    total: settings.breakDurationSeconds
                )
                .frame(width: 300)

                Spacer()

                // MARK: - Controls
                HStack(spacing: DesignTokens.spacingMD) {
                    // Postpone — medium prominence
                    Button(action: onPostpone) {
                        Label("5 More Minutes", systemImage: "clock.arrow.circlepath")
                            .padding(.horizontal, DesignTokens.spacingMD)
                            .padding(.vertical, DesignTokens.spacingXS)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.3))
                    .foregroundStyle(.white)

                    // Skip — lower prominence
                    Button(action: onSkip) {
                        Text("Skip")
                            .padding(.horizontal, DesignTokens.spacingSM)
                            .padding(.vertical, DesignTokens.spacingXS)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.6))
                }

                // Keyboard hint
                Text("Press Esc to skip  ·  Space to postpone")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, DesignTokens.spacingXL)
            }
        }
        .onKeyPress(.escape) {
            onSkip()
            return .handled
        }
        .onKeyPress(.space) {
            onPostpone()
            return .handled
        }
    }
}

// MARK: - Progress Bar

/// A thin horizontal progress bar showing break completion.
struct BreakProgressBar: View {
    let elapsed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(elapsed) / Double(total))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.15))
                    .frame(height: 4)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.5))
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .frame(height: 4)
    }
}
