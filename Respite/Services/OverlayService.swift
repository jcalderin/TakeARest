import AppKit
import SwiftUI

/// Manages full-screen break overlay windows across all connected displays.
///
/// Creates a borderless NSWindow at `.screenSaver` level for each screen.
/// The main screen gets the interactive `OverlayView` with countdown,
/// skip/postpone controls, and keyboard shortcuts. Secondary screens get
/// a simpler `SecondaryOverlayView`.
///
/// Each `show(for:engine:)` call uses the specific `BreakTimer`'s appearance
/// settings — color, opacity, message — so different timers look different.
@MainActor
@Observable
final class OverlayService {

    /// Whether the overlay is currently visible.
    private(set) var isShowing = false

    // MARK: - Dependencies

    private let timerManager: TimerManager

    // MARK: - Windows

    private var overlayWindows: [NSWindow] = []

    // MARK: - Init

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    // MARK: - Public API

    /// Show break overlays on all connected screens for the given timer.
    func show(for timer: BreakTimer, engine: TimerEngine) {
        guard !isShowing else { return }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let mainScreen = NSScreen.main ?? screens[0]

        for screen in screens {
            let isMain = (screen == mainScreen)
            let window: NSWindow

            if isMain {
                let overlayView = OverlayView(
                    engine: engine,
                    timer: timer,
                    onSkip: { [weak self] in self?.skip(engine: engine) },
                    onPostpone: { [weak self] in self?.postpone(engine: engine, minutes: 5) }
                )
                window = createOverlayWindow(screen: screen, content: overlayView)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            } else {
                let secondaryView = SecondaryOverlayView(timer: timer)
                window = createOverlayWindow(screen: screen, content: secondaryView)
                window.orderFrontRegardless()
            }

            // Fade in
            window.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = timer.dimAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 1
            }

            overlayWindows.append(window)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        isShowing = true
    }

    /// Dismiss all overlay windows.
    func dismiss() {
        guard isShowing else { return }

        let windows = overlayWindows

        if windows.isEmpty {
            tearDownAllWindows()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            for window in windows {
                window.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.tearDownAllWindows()
            }
        })
    }

    // MARK: - Private

    private func skip(engine: TimerEngine) {
        engine.skipCurrentBreak()
    }

    private func postpone(engine: TimerEngine, minutes: Int) {
        engine.postponeBreak(minutes: minutes)
    }

    private func tearDownAllWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        isShowing = false
    }

    private func createOverlayWindow<Content: View>(screen: NSScreen, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setFrame(screen.frame, display: true)
        window.ignoresMouseEvents = false
        window.sharingType = .none

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return window
    }
}
