import Foundation

/// The one ladder behind every relative age the app shows. The inbox rows and
/// the message header carried identical private copies of it, which held only
/// because there were two; the key rows are a third reader, and three copies
/// is where drift starts.
enum RelativeAge {
    /// `now` is a parameter because the feed ages its rows against a ticking
    /// clock while every other reader is happy with the moment it was built.
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
}
