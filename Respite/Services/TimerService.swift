import AppKit
import Combine
import Foundation

/// The core break timer engine.
///
/// Uses timestamp anchoring: stores `nextBreakDate` as an absolute `Date`,
/// never a decrementing counter. This is immune to sleep, App Nap,
/// timer coalescing, and background throttling.
///
/// The 1-second Timer is only for UI updates. The actual break trigger
/// is purely a date comparison: `Date() >= nextBreakDate`.
@MainActor
@Observable
final class TimerService {

    // MARK: - State Machine

    /// The possible states of the timer.
    enum State: Equatable {
        /// Timer is not running (just launched, no schedule active).
        case idle
        /// Counting down to the next break.
        case counting
        /// A break is currently active with the given end date.
        case onBreak(endsAt: Date)
        /// Paused until a specific date, or indefinitely if nil.
        case paused(until: Date?)
    }

    /// Current timer state.
    private(set) var state: State = .idle

    /// When the next break will start (absolute timestamp).
    private(set) var nextBreakDate: Date?

    /// Seconds remaining until the next break (for UI display).
    /// Updated every second while counting.
    private(set) var secondsUntilBreak: Int = 0

    /// Seconds remaining in the current break (for UI display).
    private(set) var secondsRemainingInBreak: Int = 0

    /// Number of times the user has postponed in the current break cycle.
    private(set) var postponeCount: Int = 0

    /// Maximum postpones allowed per break cycle before the button is hidden.
    static let maxPostponesPerCycle = 3

    /// Callback fired when a break should start.
    /// The overlay service will connect to this.
    var onBreakStarted: (() -> Void)?

    /// Callback fired when a break ends (naturally or skipped).
    var onBreakEnded: (() -> Void)?

    // MARK: - Dependencies

    private let settings: AppSettings
    private let dateProvider: () -> Date

    // MARK: - Internal

    private var tickTimer: AnyCancellable?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var activityToken: NSObjectProtocol?

    /// Grace period after system wake before triggering a break (seconds).
    private static let wakeGracePeriod: TimeInterval = 3.0

    // MARK: - Init

    /// - Parameters:
    ///   - settings: The app settings to read interval/duration from.
    ///   - dateProvider: Injectable date source for testing. Defaults to `Date()`.
    init(settings: AppSettings, dateProvider: @escaping () -> Date = { Date() }) {
        self.settings = settings
        self.dateProvider = dateProvider
        observeSystemEvents()
    }

    // No deinit needed: this service lives for the app's entire lifecycle.
    // Cleanup on app termination is handled by the OS.

    // MARK: - Public API

    /// Start the timer. Sets the first break date and begins counting.
    func start() {
        guard state == .idle else { return }
        scheduleNextBreak()
    }

    /// Stop the timer entirely. Returns to idle.
    func stop() {
        state = .idle
        nextBreakDate = nil
        secondsUntilBreak = 0
        secondsRemainingInBreak = 0
        stopTicking()
        endActivity()
    }

    /// Skip the next upcoming break. Resets timer to a full interval from now.
    func skipNextBreak() {
        guard state == .counting else { return }
        scheduleNextBreak()
    }

    /// Trigger a break immediately, regardless of remaining time.
    func takeBreakNow() {
        guard state == .counting else { return }
        startBreak()
    }

    /// Skip/dismiss the current active break. Resets timer.
    func skipCurrentBreak() {
        guard case .onBreak = state else { return }
        endBreak()
    }

    /// Postpone the current active break by the given number of minutes.
    /// Returns without action if the postpone limit has been reached.
    func postponeBreak(minutes: Int) {
        guard case .onBreak = state else { return }
        guard canPostpone else { return }
        postponeCount += 1
        state = .counting
        secondsRemainingInBreak = 0
        let postponeDate = dateProvider().addingTimeInterval(TimeInterval(minutes * 60))
        nextBreakDate = postponeDate
        startTicking()
        onBreakEnded?()
    }

    /// Pause the timer for the given number of minutes.
    /// Pass `nil` for indefinite pause ("Until I Resume").
    func pause(minutes: Int?) {
        guard state == .counting else { return }
        stopTicking()
        endActivity()
        if let minutes {
            let resumeDate = dateProvider().addingTimeInterval(TimeInterval(minutes * 60))
            state = .paused(until: resumeDate)
            startTicking() // keep ticking to detect when pause expires
        } else {
            state = .paused(until: nil)
        }
    }

    /// Resume from a paused state. Schedules a fresh break from now.
    func resume() {
        guard case .paused = state else { return }
        scheduleNextBreak()
    }

    // MARK: - Timer State Queries

    /// Whether the timer is actively counting down to a break.
    var isCounting: Bool {
        state == .counting
    }

    /// Whether a break is currently active.
    var isOnBreak: Bool {
        if case .onBreak = state { return true }
        return false
    }

    /// Whether the timer is paused.
    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    /// Whether the user can still postpone in this break cycle.
    var canPostpone: Bool {
        postponeCount < Self.maxPostponesPerCycle
    }

    /// Formatted countdown string for the menubar, e.g. "14:32".
    var countdownFormatted: String {
        let total = isCounting ? secondsUntilBreak : secondsRemainingInBreak
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Pause time remaining, formatted. Returns nil if not paused.
    var pauseRemainingFormatted: String? {
        guard case .paused(let until) = state, let until else { return nil }
        let remaining = max(0, Int(until.timeIntervalSince(dateProvider())))
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Private: Scheduling

    private func scheduleNextBreak() {
        let interval = TimeInterval(settings.breakIntervalMinutes * 60)
        nextBreakDate = dateProvider().addingTimeInterval(interval)
        state = .counting
        postponeCount = 0
        startTicking()
    }

    private func startBreak() {
        let duration = TimeInterval(settings.breakDurationSeconds)
        let endsAt = dateProvider().addingTimeInterval(duration)
        state = .onBreak(endsAt: endsAt)
        secondsRemainingInBreak = settings.breakDurationSeconds
        endActivity()
        onBreakStarted?()
    }

    private func endBreak() {
        state = .counting
        secondsRemainingInBreak = 0
        onBreakEnded?()
        scheduleNextBreak()
    }

    // MARK: - Private: Tick Loop

    private func startTicking() {
        stopTicking()
        tickTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        // Immediate first tick
        tick()
    }

    private func stopTicking() {
        tickTimer?.cancel()
        tickTimer = nil
    }

    private func tick() {
        let now = dateProvider()

        switch state {
        case .idle:
            stopTicking()

        case .counting:
            guard let breakDate = nextBreakDate else { return }
            let remaining = breakDate.timeIntervalSince(now)
            if remaining <= 0 {
                startBreak()
            } else {
                secondsUntilBreak = Int(ceil(remaining))
                // Prevent App Nap during the final 60 seconds
                if remaining <= 60 {
                    beginActivityIfNeeded()
                }
            }

        case .onBreak(let endsAt):
            let remaining = endsAt.timeIntervalSince(now)
            if remaining <= 0 {
                endBreak()
            } else {
                secondsRemainingInBreak = Int(ceil(remaining))
            }

        case .paused(let until):
            if let until, now >= until {
                resume()
            }
        }
    }

    // MARK: - Private: System Events

    private func observeSystemEvents() {
        let center = NSWorkspace.shared.notificationCenter

        let wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemWake()
            }
        }

        let sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemSleep()
            }
        }

        workspaceObservers = [wakeObserver, sleepObserver]
    }

    /// Recalculates the timer after the system wakes from sleep.
    /// Internal (not private) so tests can call it directly without
    /// going through the async notification path.
    func handleSystemWake() {
        guard state == .counting, let breakDate = nextBreakDate else { return }
        let now = dateProvider()

        if now >= breakDate {
            // Break was due during sleep. Wait a grace period before firing
            // so the user has a moment to orient after opening the lid.
            let graceDate = now.addingTimeInterval(Self.wakeGracePeriod)
            nextBreakDate = graceDate
            startTicking()
        } else {
            // Break is still in the future, just resume ticking
            startTicking()
        }
    }

    private func handleSystemSleep() {
        // Stop the display timer to save resources during sleep.
        // On wake, handleSystemWake recalculates.
        stopTicking()
        endActivity()
    }

    // MARK: - Private: App Nap Prevention

    private func beginActivityIfNeeded() {
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Break timer about to fire"
        )
    }

    private func endActivity() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }
}
