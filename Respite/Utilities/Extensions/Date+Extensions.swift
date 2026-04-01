import Foundation

extension Date {

    /// Compact countdown string from this date to another date.
    /// Returns "0:00" if the target is in the past.
    func countdownString(to target: Date) -> String {
        let remaining = max(0, target.timeIntervalSince(self))
        let totalSeconds = Int(ceil(remaining))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
