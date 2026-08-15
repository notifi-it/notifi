import Foundation

enum RelativeAge {
    static func string(since basis: Date, at now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(basis)))
        switch seconds {
        case ..<60: return Copy.Age.now
        case ..<3_600: return Copy.Age.minutes("\(seconds / 60)")
        case ..<86_400: return Copy.Age.hours("\(seconds / 3_600)")
        case ..<604_800: return Copy.Age.days("\(seconds / 86_400)")
        default: return Copy.Age.weeks("\(seconds / 604_800)")
        }
    }

    // "now" cannot take the "{relative} ago" wrapper — "used now ago" — so the
    // under-a-minute case has its own phrasing and every "ago" label goes
    // through here rather than composing the two copy keys itself.
    static func agoString(since basis: Date, at now: Date = Date()) -> String {
        if now.timeIntervalSince(basis) < 60 { return Copy.Age.justNow }
        return Copy.Age.ago(string(since: basis, at: now))
    }
}
