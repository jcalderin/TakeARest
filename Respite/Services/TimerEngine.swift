import AppKit
import Combine
import Foundation

/// A single break timer engine, parameterized by a `BreakTimer` configuration.
///
/// Uses timestamp anchoring: stores `nextBreakDate` as an absolute `Date`,
/// never a decrementing counter. Immune to sleep, App Nap, timer coalescing,
/// and background throttling.
///
/// Each `TimerEngine` instance is independent — multiple engines can run
/// concurrently, managed by `TimerManager`.
@MainActor
@Observable
final class TimerEngine: Identifiable {

    nonisolated let id: UUID

    // MARK: - State Machine

    /// The possible states of the engine.
    enum State: Equatable {
        /// Engine is not running.
        case idle
        /// Counting down to the next break.
        case counting
        /// A break is currently active with the given end date.
        case onBreak(endsAt: Date)
        /// Paused until a specific date, or indefinitely if nil.
        case paused(until: Date?)
    }

    /// Current engine state.
    private(set) var state: State = .idle

    /// The timer configuration this engine is running.
    private(set) var breakTimer: BreakTimer

    /// When the next break will start (absolute timestamp).
    private(set) var nextBreakDate: Date?

    /// Seconds remaining until the next break (for UI display).
    private(set) var secondsUntilBreak: Int = 0

    /// Seconds remaining in the current break (for UI display).
    private(set) var secondsRemainingInBreak: Int = 0

    /// Number of times the user has postponed in the current break cycle.
    private(set) var postponeCount: Int = 0

    /// Maximum postpones allowed per break cycle.
    static let maxPostponesPerCycle = 3

    /// Callback fired when a break should start. Passes the BreakTimer config.
    var onBreakStarted: ((BreakTimer) -> Void)?

    /// Callback fired when a break ends (naturally or skipped).
    var onBreakEnded: ((BreakTimer) -> Void)?

    // MARK: - Identity

    /// Stable identifier matching the BreakTimer's id.
    let timerID: UUID

    // MARK: - Dependencies

    private let dateProvider: () -> Date

    // MARK: - Internal

    private var tickTimer: AnyCancellable?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var activityToken: NSObjectProtocol?

    /// Whether the current activity assertion also blocks idle system sleep.
    /// Tracked so we only re-acquire the assertion when the phase changes.
    private var activityBlocksSleep = false

    /// Grace period after system wake before triggering a break (seconds).
    private static let wakeGracePeriod: TimeInterval = 3.0

    // MARK: - Init

    /// - Parameters:
    ///   - breakTimer: The timer configuration to run.
    ///   - dateProvider: Injectable date source for testing. Defaults to `Date()`.
    init(breakTimer: BreakTimer, dateProvider: @escaping () -> Date = { Date() }) {
        self.id = breakTimer.id
        self.timerID = breakTimer.id
        self.breakTimer = breakTimer
        self.dateProvider = dateProvider
        observeSystemEvents()
    }

    // MARK: - Configuration Update

    /// Update the engine's configuration live (e.g. when user edits in Preferences).
    /// If the interval changed while counting, reschedules appropriately.
    func updateConfiguration(_ newTimer: BreakTimer) {
        let oldInterval = breakTimer.breakIntervalMinutes
        breakTimer = newTimer

        // If interval changed while counting, reschedule
        if state == .counting && newTimer.breakIntervalMinutes != oldInterval {
            scheduleNextBreak()
        }
    }

    // MARK: - Public API

    /// Start the engine. Sets the first break date and begins counting.
    func start() {
        guard state == .idle else { return }
        scheduleNextBreak()
    }

    /// Stop the engine entirely. Returns to idle.
    func stop() {
        state = .idle
        nextBreakDate = nil
        secondsUntilBreak = 0
        secondsRemainingInBreak = 0
        stopTicking()
        endActivity()
    }

    /// Skip the next upcoming break. Resets to a full interval from now.
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
        onBreakEnded?(breakTimer)
    }

    /// Pause the engine for the given number of minutes.
    /// Pass `nil` for indefinite pause ("Until I Resume").
    func pause(minutes: Int?) {
        guard state == .counting else { return }
        stopTicking()
        endActivity()
        if let minutes {
            let resumeDate = dateProvider().addingTimeInterval(TimeInterval(minutes * 60))
            state = .paused(until: resumeDate)
            startTicking()
        } else {
            state = .paused(until: nil)
        }
    }

    /// Resume from a paused state. Schedules a fresh break from now.
    func resume() {
        guard case .paused = state else { return }
        scheduleNextBreak()
    }

    // MARK: - State Queries

    var isCounting: Bool { state == .counting }

    var isOnBreak: Bool {
        if case .onBreak = state { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    var isIdle: Bool { state == .idle }

    /// Whether the user can still postpone in this break cycle.
    var canPostpone: Bool {
        postponeCount < Self.maxPostponesPerCycle
    }

    /// Formatted countdown string, e.g. "14:32".
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
        let now = dateProvider()
        let interval = TimeInterval(breakTimer.breakIntervalMinutes * 60)
        nextBreakDate = now.addingTimeInterval(interval)
        state = .counting
        postponeCount = 0
        startTicking()
    }

    private func startBreak() {
        let now = dateProvider()
        let duration = TimeInterval(breakTimer.breakDurationSeconds)
        let endsAt = now.addingTimeInterval(duration)
        state = .onBreak(endsAt: endsAt)
        secondsRemainingInBreak = breakTimer.breakDurationSeconds
        endActivity()
        onBreakStarted?(breakTimer)
    }

    private func endBreak() {
        state = .counting
        secondsRemainingInBreak = 0
        onBreakEnded?(breakTimer)
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
                // Prevent App Nap for the whole countdown so the 1s tick keeps
                // firing over long idle periods; in the final minute also block
                // idle sleep so the break reliably fires.
                updateActivity(blockSleep: remaining <= 60)
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

    /// Recalculates after system wake. Internal for test access.
    ///
    /// The tick loop is stopped on sleep, so every non-idle state must restart
    /// it here — otherwise a timed pause never resumes and an interrupted break
    /// never ends.
    func handleSystemWake() {
        let now = dateProvider()

        switch state {
        case .counting:
            guard let breakDate = nextBreakDate else { return }
            // If we slept past the break, fire after a short grace period.
            if now >= breakDate {
                nextBreakDate = now.addingTimeInterval(Self.wakeGracePeriod)
            }
            startTicking()

        case .onBreak:
            startTicking()

        case .paused(let until):
            // Only timed pauses need the tick loop (to detect resume time).
            guard let until else { return }
            if now >= until {
                resume()
            } else {
                startTicking()
            }

        case .idle:
            break
        }
    }

    private func handleSystemSleep() {
        stopTicking()
        endActivity()
    }

    // MARK: - Private: App Nap Prevention

    /// Hold (or upgrade) an activity assertion while counting down.
    ///
    /// - `blockSleep == false`: prevent App Nap only, still allowing the Mac to
    ///   sleep when idle — used for the bulk of the countdown.
    /// - `blockSleep == true`: also block idle system sleep so the imminent
    ///   break fires — used in the final minute.
    ///
    /// Re-acquires only when the phase changes, so it's cheap to call each tick.
    private func updateActivity(blockSleep: Bool) {
        guard activityToken == nil || blockSleep != activityBlocksSleep else { return }
        endActivity()
        activityBlocksSleep = blockSleep
        let options: ProcessInfo.ActivityOptions = blockSleep
            ? [.userInitiated, .idleSystemSleepDisabled]
            : [.userInitiatedAllowingIdleSystemSleep]
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: "Break timer '\(breakTimer.name)' counting down"
        )
    }

    private func endActivity() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
        activityBlocksSleep = false
    }
}
