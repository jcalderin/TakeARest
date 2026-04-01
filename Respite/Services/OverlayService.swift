import AppKit
import SwiftUI

/// Manages the full-screen break overlay window.
///
/// Creates a borderless NSWindow at `.screenSaver` level that appears above
/// everything — including full-screen apps, the Dock, and the menu bar.
/// Hosts a SwiftUI `OverlayView` via `NSHostingView`.
///
/// Phase 6: Single main screen. Phase 8 extends to all connected displays.
@MainActor
@Observable
final class OverlayService {

    /// Whether the overlay is currently visible.
    private(set) var isShowing = false

    // MARK: - Dependencies

    private let settings: AppSettings
    private let timerService: TimerService

    // MARK: - Window

    private var overlayWindow: NSWindow?

    // MARK: - Init

    init(settings: AppSettings, timerService: TimerService) {
        self.settings = settings
        self.timerService = timerService
    }

    // MARK: - Public API

    /// Show the break overlay on the main screen.
    func show() {
        guard !isShowing else { return }
        guard let screen = NSScreen.main else { return }

        let overlayView = OverlayView(
            timerService: timerService,
            settings: settings,
            onSkip: { [weak self] in self?.skip() },
            onPostpone: { [weak self] in self?.postpone(minutes: 5) }
        )

        let window = createOverlayWindow(screen: screen, content: overlayView)
        overlayWindow = window

        // Show window — orderFrontRegardless is required for LSUIElement apps
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Activate the app so the overlay can receive keyboard events
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Fade in
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = settings.dimAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 1
        }

        isShowing = true
    }

    /// Dismiss the overlay immediately.
    func dismiss() {
        guard isShowing else { return }

        // Quick fade out
        if let window = overlayWindow {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    self?.tearDownWindow()
                }
            })
        } else {
            tearDownWindow()
        }
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

    private func tearDownWindow() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
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
