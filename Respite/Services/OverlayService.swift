import AppKit
import SwiftUI

/// Manages full-screen break overlay windows across all connected displays.
///
/// Creates a borderless NSWindow at `.screenSaver` level for each screen.
/// The main screen gets the interactive `OverlayView` with countdown,
/// skip/postpone controls, and keyboard shortcuts. Secondary screens get
/// a simpler `SecondaryOverlayView` — just the dimmed background and
/// break message — to avoid multiple key windows fighting for focus.
@MainActor
@Observable
final class OverlayService {

    /// Whether the overlay is currently visible.
    private(set) var isShowing = false

    // MARK: - Dependencies

    private let settings: AppSettings
    private let timerService: TimerService

    // MARK: - Windows

    /// One overlay window per connected screen.
    private var overlayWindows: [NSWindow] = []

    // MARK: - Init

    init(settings: AppSettings, timerService: TimerService) {
        self.settings = settings
        self.timerService = timerService
    }

    // MARK: - Public API

    /// Show break overlays on all connected screens.
    func show() {
        guard !isShowing else { return }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let mainScreen = NSScreen.main ?? screens[0]

        for screen in screens {
            let isMain = (screen == mainScreen)
            let window: NSWindow

            if isMain {
                let overlayView = OverlayView(
                    timerService: timerService,
                    settings: settings,
                    onSkip: { [weak self] in self?.skip() },
                    onPostpone: { [weak self] in self?.postpone(minutes: 5) }
                )
                window = createOverlayWindow(screen: screen, content: overlayView)

                // Only the main screen window is key (receives keyboard events)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            } else {
                let secondaryView = SecondaryOverlayView(settings: settings)
                window = createOverlayWindow(screen: screen, content: secondaryView)

                // Secondary windows show but don't become key
                window.orderFrontRegardless()
            }

            // Fade in
            window.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = settings.dimAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 1
            }

            overlayWindows.append(window)
        }

        // Activate the app so the main overlay can receive keyboard events
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

        // Fade out all windows simultaneously
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

    private func skip() {
        // Tell the timer the break was skipped — this fires onBreakEnded
        // which calls dismiss() via the callback wired in RespiteApp.
        timerService.skipCurrentBreak()
    }

    private func postpone(minutes: Int) {
        // Tell the timer to postpone — this fires onBreakEnded
        // which calls dismiss() via the callback wired in RespiteApp.
        timerService.postponeBreak(minutes: minutes)
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

        // Above everything: full-screen apps, Dock, menu bar
        window.level = .screenSaver

        // Appear on all Spaces, float above full-screen apps, don't show in Expose
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        // Transparent window — SwiftUI content provides the visual background
        window.isOpaque = false
        window.backgroundColor = .clear

        // Cover the entire screen including menu bar area
        window.setFrame(screen.frame, display: true)

        // Accept mouse and keyboard events
        window.ignoresMouseEvents = false

        // Exclude from screen sharing (Zoom, Teams, etc.)
        window.sharingType = .none

        // Host SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return window
    }
}
