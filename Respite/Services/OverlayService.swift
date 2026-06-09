import AppKit
import OSLog
import SwiftUI

private let log = Logger(subsystem: "com.cholas.Respite", category: "overlay")

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

    /// Local key monitor, active only while the overlay is shown.
    private var keyMonitor: Any?

    /// The app that was frontmost before the overlay stole focus, so it can be
    /// reactivated on dismiss (skip/postpone/natural end).
    private var previousApp: NSRunningApplication?

    // MARK: - Init

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    // MARK: - Public API

    /// Show break overlays on all connected screens for the given timer.
    func show(for timer: BreakTimer, engine: TimerEngine) {
        guard !isShowing else {
            log.warning("show(\(timer.name, privacy: .public)) ignored — already showing")
            return
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            log.error("show(\(timer.name, privacy: .public)) — no screens")
            return
        }

        // Remember who had focus so we can hand it back on dismiss (unless it
        // was us, e.g. the Preferences window).
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = (frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier) ? nil : frontmost
        // Pick the interactive screen by index. Comparing NSScreen instances
        // directly can fail (NSScreen.main may be a different instance than the
        // ones in .screens), which would leave zero interactive overlays.
        let mainIndex = screens.firstIndex { $0 == NSScreen.main } ?? 0
        log.info("show(\(timer.name, privacy: .public)) — screens=\(screens.count) mainIndex=\(mainIndex)")

        for (index, screen) in screens.enumerated() {
            let isMain = (index == mainIndex)
            log.info("  window[\(index)] isMain=\(isMain) frame=\(NSStringFromRect(screen.frame), privacy: .public)")
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
        installKeyMonitor(for: engine)
        isShowing = true
    }

    /// While the overlay is up: Esc → skip, Space → postpone. Other un-modified
    /// keys are swallowed so they don't beep or leak to apps behind the overlay;
    /// modifier shortcuts (Cmd+Q, etc.) pass through.
    private func installKeyMonitor(for engine: TimerEngine) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                return event
            }
            switch event.keyCode {
            case 53: // Escape
                self.skip(engine: engine)
            case 49: // Space
                if engine.canPostpone { self.postpone(engine: engine, minutes: 5) }
            default:
                break
            }
            return nil // swallow plain keys → no system beep
        }
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
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        isShowing = false

        // Hand focus back to whatever the user was in before the break.
        if let previousApp {
            previousApp.activate()
            self.previousApp = nil
        }
    }

    private func createOverlayWindow<Content: View>(screen: NSScreen, content: Content) -> NSWindow {
        let window = KeyableOverlayWindow(
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

/// Borderless overlay window that can become **key** (so the key monitor gets
/// Esc/Space) but never **main** — becoming main is what disturbed the agent
/// app's scene management and surfaced the Settings window.
private final class KeyableOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Pre-Warning HUD

/// Shows the "break is coming" heads-up (pill / buttons / bar) before a break.
///
/// Uses a **non-activating** panel so it never steals keyboard focus while the
/// user is still typing. Sits at `.floating` level (below the break overlay's
/// `.screenSaver`), centered on the active screen.
@MainActor
@Observable
final class PreWarnService {

    private(set) var isShowing = false
    private var panels: [NSPanel] = []

    func show(
        for timer: BreakTimer,
        engine: TimerEngine,
        onStartNow: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        guard timer.preWarnStyle != .off, !isShowing else { return }

        // Watermark spans every screen (so it's unmissable on a wide setup);
        // the other styles sit on the active screen only.
        let screens = timer.preWarnStyle.spansAllScreens
            ? NSScreen.screens
            : [NSScreen.main ?? NSScreen.screens.first].compactMap { $0 }

        for screen in screens {
            let panel = NSPanel(
                contentRect: Self.frame(for: timer.preWarnStyle, on: screen),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = (timer.preWarnStyle != .bar && timer.preWarnStyle != .watermark)
            panel.ignoresMouseEvents = timer.preWarnStyle.isClickThrough
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.hidesOnDeactivate = false

            let host = NSHostingView(rootView: PreWarnView(
                timer: timer, engine: engine, onStartNow: onStartNow, onSkip: onSkip
            ))
            host.frame = panel.contentView!.bounds
            host.autoresizingMask = [.width, .height]
            panel.contentView = host
            panel.orderFrontRegardless()

            panels.append(panel)
        }
        isShowing = !panels.isEmpty
    }

    func dismiss() {
        for panel in panels { panel.orderOut(nil) }
        panels.removeAll()
        isShowing = false
    }

    /// Watermark fills the whole screen; bar hugs the top edge; pill/HUD are
    /// centered in the visible area (clear of the menu bar / Dock).
    private static func frame(for style: PreWarnStyle, on screen: NSScreen) -> NSRect {
        let area = screen.visibleFrame
        switch style {
        case .watermark:
            return screen.frame
        case .bar:
            let h: CGFloat = 6
            return NSRect(x: area.minX, y: area.maxY - h, width: area.width, height: h)
        case .hud:
            let w: CGFloat = 380, h: CGFloat = 110
            return NSRect(x: area.midX - w / 2, y: area.midY - h / 2, width: w, height: h)
        case .pill, .off:
            let w: CGFloat = 260, h: CGFloat = 64
            return NSRect(x: area.midX - w / 2, y: area.midY - h / 2, width: w, height: h)
        }
    }
}
