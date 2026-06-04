import SwiftUI

/// The full-screen break overlay content.
///
/// Shown inside the overlay NSWindow on the main display. Uses the
/// specific `BreakTimer`'s appearance settings for color, opacity,
/// and message. Receives its engine for countdown and state queries.
struct OverlayView: View {
    var engine: TimerEngine
    var timer: BreakTimer
    var onSkip: () -> Void
    var onPostpone: () -> Void

    var body: some View {
        ZStack {
            // MARK: - Background
            timer.overlayColor
                .opacity(timer.overlayOpacity)
                .ignoresSafeArea()

            // MARK: - Content
            VStack(spacing: DesignTokens.spacingXL) {
                Spacer()

                // Break message
                Text(timer.breakMessage)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .foregroundStyle(.white)

                // Countdown
                if timer.showCountdown {
                    Text(engine.countdownFormatted)
                        .respiteHero()
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.3), value: engine.secondsRemainingInBreak)
                }

                // Progress bar
                BreakProgressBar(
                    elapsed: timer.breakDurationSeconds - engine.secondsRemainingInBreak,
                    total: timer.breakDurationSeconds
                )
                .frame(width: 300)

                Spacer()

                // MARK: - Controls
                HStack(spacing: DesignTokens.spacingMD) {
                    // Postpone — hidden after max postpones
                    if engine.canPostpone {
                        Button(action: onPostpone) {
                            Label("5 More Minutes", systemImage: "clock.arrow.circlepath")
                                .padding(.horizontal, DesignTokens.spacingMD)
                                .padding(.vertical, DesignTokens.spacingXS)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.3))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                    }

                    // Skip
                    Button(action: onSkip) {
                        Text("Skip")
                            .padding(.horizontal, DesignTokens.spacingSM)
                            .padding(.vertical, DesignTokens.spacingXS)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.6))
                }
                .animation(.easeInOut(duration: 0.3), value: engine.canPostpone)

                // Keyboard hint — order matches the buttons above
                // (Postpone on the left with Space, Skip on the right with Esc).
                Text(engine.canPostpone
                     ? "Space to postpone  ·  Esc to skip"
                     : "Esc to skip")
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
            guard engine.canPostpone else { return .ignored }
            onPostpone()
            return .handled
        }
    }
}

// MARK: - Progress Bar

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
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.15))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.5))
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .frame(height: 4)
    }
}
