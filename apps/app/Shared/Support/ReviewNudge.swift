import Foundation

/// Decides when the system rating prompt is worth asking for.
///
/// The prompt itself is Apple's: it may not appear even when requested, and it
/// shows at most three times a year. This type only guards the request — the
/// tenth opened message, once per install. Ten opens is someone the app is
/// working for; asking earlier interrupts a person still deciding, and asking
/// repeatedly is what the once-per-install flag exists to prevent. The
/// Settings row is the deliberate path; this is the only automatic one.
enum ReviewNudge {
    private static let countKey = "reviewNudgeOpens"
    private static let askedKey = "reviewNudgeAsked"

    /// Called on every message-detail appearance. Returns true exactly once,
    /// on the open that crosses the threshold.
    static func shouldAskAfterMessageOpen() -> Bool {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: askedKey) else { return false }
        let opens = defaults.integer(forKey: countKey) + 1
        defaults.set(opens, forKey: countKey)
        guard opens >= 10 else { return false }
        defaults.set(true, forKey: askedKey)
        return true
    }
}
