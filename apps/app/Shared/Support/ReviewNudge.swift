import Foundation

enum ReviewNudge {
    private static let countKey = "reviewNudgeOpens"
    private static let askedKey = "reviewNudgeAsked"

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
