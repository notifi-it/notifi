import Foundation

enum ReviewNudge {
    private static let countKey = "reviewNudgeOpens"
    private static let askedKey = "reviewNudgeAsked"
    private static let milestones = [10, 50]

    static func shouldAskAfterMessageOpen() -> Bool {
        let defaults = UserDefaults.standard
        let asked = defaults.integer(forKey: askedKey)
        guard asked < milestones.count else { return false }
        let opens = defaults.integer(forKey: countKey) + 1
        defaults.set(opens, forKey: countKey)
        guard opens >= milestones[asked] else { return false }
        defaults.set(asked + 1, forKey: askedKey)
        return true
    }
}
