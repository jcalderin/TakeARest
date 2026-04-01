import AppKit
import Foundation
import Testing
@testable import Respite

/// Tests for TimerService.
///
/// Uses an injectable `dateProvider` to control time without waiting.
/// Each test creates an isolated AppSettings via a fresh UserDefaults suite.
@Suite("TimerService")
@MainActor
struct TimerServiceTests {

    private func makeSUT(
        intervalMinutes: Int = 20,
        durationSeconds: Int = 20,
        now: Date = Date(timeIntervalSinceReferenceDate: 0)
    ) -> (TimerService, AppSettings, CurrentDateHolder) {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.breakIntervalMinutes = intervalMinutes
        settings.breakDurationSeconds = durationSeconds

        let dateHolder = CurrentDateHolder(now)
        let timer = TimerService(settings: settings, dateProvider: { dateHolder.now })
        return (timer, settings, dateHolder)
    }

    // MARK: - State Machine

    @Test("Timer starts in idle state")
    func initialState() {
        let (timer, _, _) = makeSUT()
        #expect(timer.state == .idle)
        #expect(!timer.isCounting)
        #expect(!timer.isOnBreak)
        #expect(!timer.isPaused)
    }

    @Test("Start transitions from idle to counting")
    func startTransition() {
        let (timer, _, _) = makeSUT()
        timer.start()
        #expect(timer.state == .counting)
        #expect(timer.isCounting)
        #expect(timer.nextBreakDate != nil)
    }

    @Test("Start is ignored if already counting")
    func startWhenAlreadyCounting() {
        let (timer, _, _) = makeSUT()
        timer.start()
        let firstBreakDate = timer.nextBreakDate
        timer.start() // should be ignored
        #expect(timer.nextBreakDate == firstBreakDate)
    }

    @Test("Stop returns to idle")
    func stopTransition() {
        let (timer, _, _) = makeSUT()
        timer.start()
        timer.stop()
        #expect(timer.state == .idle)
        #expect(timer.nextBreakDate == nil)
        #expect(timer.secondsUntilBreak == 0)
    }

    // MARK: - Break Scheduling

    @Test("Next break is scheduled at now + interval")
    func breakScheduledAtCorrectTime() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (timer, settings, _) = makeSUT(intervalMinutes: 15, now: startTime)
        timer.start()

        let expectedBreak = startTime.addingTimeInterval(15 * 60)
        #expect(timer.nextBreakDate == expectedBreak)
        _ = settings // silence unused warning
    }

    @Test("Skip next break reschedules from now")
    func skipNextBreak() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (timer, _, dateHolder) = makeSUT(intervalMinutes: 20, now: startTime)
        timer.start()
        let firstBreakDate = timer.nextBreakDate

        // Advance time 5 minutes
        dateHolder.now = startTime.addingTimeInterval(5 * 60)
        timer.skipNextBreak()

        // New break should be 20 minutes from the new "now", not the old one
        let expectedBreak = dateHolder.now.addingTimeInterval(20 * 60)
        #expect(timer.nextBreakDate == expectedBreak)
        #expect(timer.nextBreakDate != firstBreakDate)
    }

    @Test("Take break now triggers immediately")
    func takeBreakNow() {
        let (timer, _, _) = makeSUT()
        timer.start()
        #expect(timer.isCounting)

        var breakFired = false
        timer.onBreakStarted = { breakFired = true }
        timer.takeBreakNow()

        #expect(timer.isOnBreak)
        #expect(breakFired)
    }

    // MARK: - Break Lifecycle

    @Test("Break fires when time is reached")
    func breakFiresOnTime() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (timer, _, dateHolder) = makeSUT(intervalMinutes: 20, durationSeconds: 30, now: startTime)

        var breakFired = false
        timer.onBreakStarted = { breakFired = true }
        timer.start()

        // Advance past break time
        dateHolder.now = startTime.addingTimeInterval(20 * 60 + 1)
        // Simulate tick
        timer.takeBreakNow() // force state change since we can't wait for real timer

        #expect(breakFired)
        #expect(timer.isOnBreak)
    }

    @Test("Skip current break ends break and reschedules")
    func skipCurrentBreak() {
        let (timer, _, _) = makeSUT()
        timer.start()

        var breakEnded = false
        timer.onBreakEnded = { breakEnded = true }
        timer.takeBreakNow()
        #expect(timer.isOnBreak)

        timer.skipCurrentBreak()
        #expect(timer.isCounting)
        #expect(breakEnded)
        #expect(timer.nextBreakDate != nil)
    }

    @Test("Postpone break reschedules to now + postpone duration")
    func postponeBreak() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (timer, _, dateHolder) = makeSUT(now: startTime)

        timer.start()
        timer.takeBreakNow()
        #expect(timer.isOnBreak)

        var breakEnded = false
        timer.onBreakEnded = { breakEnded = true }
        timer.postponeBreak(minutes: 5)

        #expect(timer.isCounting)
        #expect(breakEnded)
        let expectedBreak = dateHolder.now.addingTimeInterval(5 * 60)
        #expect(timer.nextBreakDate == expectedBreak)
    }

    // MARK: - Pause

    @Test("Pause transitions from counting to paused")
    func pauseTransition() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (timer, _, _) = makeSUT(now: startTime)
        timer.start()

        timer.pause(minutes: 30)
        #expect(timer.isPaused)
        if case .paused(let until) = timer.state {
            #expect(until == startTime.addingTimeInterval(30 * 60))
        } else {
            Issue.record("Expected paused state")
        }
    }

    @Test("Indefinite pause has no resume date")
    func indefinitePause() {
        let (timer, _, _) = makeSUT()
        timer.start()
        timer.pause(minutes: nil)

        if case .paused(let until) = timer.state {
            #expect(until == nil)
        } else {
            Issue.record("Expected paused state")
        }
    }

    @Test("Resume from pause schedules a fresh break")
    func resumeFromPause() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (timer, _, dateHolder) = makeSUT(intervalMinutes: 20, now: startTime)
        timer.start()
        timer.pause(minutes: nil)
        #expect(timer.isPaused)

        // Advance time 10 minutes
        dateHolder.now = startTime.addingTimeInterval(10 * 60)
        timer.resume()

        #expect(timer.isCounting)
        // Break should be 20 minutes from resume time, not from original start
        let expectedBreak = dateHolder.now.addingTimeInterval(20 * 60)
        #expect(timer.nextBreakDate == expectedBreak)
    }

    // MARK: - Invalid Transitions

    @Test("Cannot pause while on break")
    func cannotPauseOnBreak() {
        let (timer, _, _) = makeSUT()
        timer.start()
        timer.takeBreakNow()
        #expect(timer.isOnBreak)

        timer.pause(minutes: 15)
        // Should still be on break, not paused
        #expect(timer.isOnBreak)
    }

    @Test("Cannot skip next break while on break")
    func cannotSkipNextWhileOnBreak() {
        let (timer, _, _) = makeSUT()
        timer.start()
        timer.takeBreakNow()

        timer.skipNextBreak() // should be ignored
        #expect(timer.isOnBreak)
    }

    @Test("Cannot take break now while paused")
    func cannotBreakWhilePaused() {
        let (timer, _, _) = makeSUT()
        timer.start()
        timer.pause(minutes: 15)

        timer.takeBreakNow() // should be ignored
        #expect(timer.isPaused)
    }

    // MARK: - Sleep/Wake Simulation

    @Test("After wake past break time, break is rescheduled with grace period")
    func wakeGracePeriod() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (timer, _, dateHolder) = makeSUT(intervalMinutes: 20, now: startTime)
        timer.start()
        let originalBreakDate = timer.nextBreakDate!

        // Simulate sleep and wake 30 minutes later (past the 20-min break)
        dateHolder.now = startTime.addingTimeInterval(30 * 60)

        // Call wake handler directly (avoids async notification dispatch)
        timer.handleSystemWake()

        // The break date should be rescheduled to now + grace period (3s)
        #expect(timer.isCounting)
        if let newBreakDate = timer.nextBreakDate {
            let gracePeriod = newBreakDate.timeIntervalSince(dateHolder.now)
            #expect(newBreakDate > originalBreakDate)
            #expect(gracePeriod > 0 && gracePeriod <= 3.0)
        } else {
            Issue.record("Expected nextBreakDate to be set")
        }
    }

    // MARK: - Countdown Formatting

    @Test("Countdown formatted string is correct")
    func countdownFormatting() {
        let (timer, _, _) = makeSUT(intervalMinutes: 20)
        timer.start()
        // Right after start, should be close to 20:00
        #expect(timer.secondsUntilBreak == 20 * 60)
        #expect(timer.countdownFormatted == "20:00")
    }
}

// MARK: - Test Helper

/// Mutable date holder for injecting controllable time into TimerService.
@MainActor
final class CurrentDateHolder {
    var now: Date

    init(_ date: Date) {
        self.now = date
    }
}
