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

                // Keyboard hint — order matches the buttons (Postpone/Space left,
                // Skip/Esc right).
                Text(engine.canPostpone
                     ? "Space to postpone  ·  Esc to skip"
                     : "Esc to skip")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, DesignTokens.spacingXL)
            }
        }
    }
}

// MARK: - Pre-Warning Views

/// Routes to the configured heads-up style, reading the live countdown from
/// the engine. Centered content; never interactive except the `.hud` buttons.
struct PreWarnView: View {
    var timer: BreakTimer
    var engine: TimerEngine
    var onStartNow: () -> Void
    var onSkip: () -> Void

    private var seconds: Int { max(0, engine.secondsUntilBreak) }

    var body: some View {
        switch timer.preWarnStyle {
        case .bar:
            PreWarnBar(progress: progress, color: timer.overlayColor)
        case .pill:
            centered { PreWarnPill(seconds: seconds, color: timer.overlayColor) }
        case .hud:
            centered {
                PreWarnHUD(seconds: seconds, color: timer.overlayColor,
                           onStartNow: onStartNow, onSkip: onSkip)
            }
        case .watermark:
            PreWarnWatermark(seconds: seconds, color: timer.overlayColor)
        case .off:
            EmptyView()
        }
    }

    /// Fraction of the lead time elapsed (0 → 1 as the break approaches).
    private var progress: Double {
        let lead = Double(max(1, timer.preWarnSeconds))
        return min(1, max(0, 1 - Double(seconds) / lead))
    }

    private func centered<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        ZStack { Color.clear; content() }
    }
}

private struct PreWarnPill: View {
    let seconds: Int
    let color: Color

    var body: some View {
        HStack(spacing: DesignTokens.spacingXS) {
            Image(systemName: "cup.and.saucer.fill")
                .foregroundStyle(color)
            Text("Break in \(seconds)s")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
        .shadow(radius: 8, y: 2)
    }
}

private struct PreWarnHUD: View {
    let seconds: Int
    let color: Color
    var onStartNow: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(color)
                Text("Break in \(seconds)s")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            HStack(spacing: DesignTokens.spacingSM) {
                Button("Start now", action: onStartNow)
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                Button("Skip", action: onSkip)
                    .buttonStyle(.bordered)
            }
            .controlSize(.regular)
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingMD)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMD)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(radius: 10, y: 2)
    }
}

private struct PreWarnBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * progress)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
    }
}

/// See-through countdown tiled diagonally across the whole screen — repeated so
/// it's easy to spot anywhere (even on a dark desktop), but faint enough to read
/// and click through what's behind it.
private struct PreWarnWatermark: View {
    let seconds: Int
    let color: Color

    private let tileW: CGFloat = 320
    private let tileH: CGFloat = 170

    var body: some View {
        Canvas { context, size in
            let resolved = context.resolve(
                Text("Break in \(seconds)s")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.28))
            )

            // Rotate the whole pattern about the screen's center.
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(-30))
            context.translateBy(x: -size.width / 2, y: -size.height / 2)

            // Tile over an area larger than the screen so corners fill in once
            // rotated; offset every other row for a brick layout.
            let pad = max(size.width, size.height) * 0.7
            var row = 0
            var y = -pad
            while y < size.height + pad {
                let xShift = row.isMultiple(of: 2) ? 0 : tileW / 2
                var x = -pad + xShift
                while x < size.width + pad {
                    context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
                    x += tileW
                }
                y += tileH
                row += 1
            }
        }
        .shadow(color: .black.opacity(0.22), radius: 2)
        .allowsHitTesting(false)
        .ignoresSafeArea()
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
