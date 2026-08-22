import Foundation
import SwiftData

@Model
final class SyncState {
    var bookmark: Int
    var failureFirstSeen: [String: Double]

    init(bookmark: Int = 0, failureFirstSeen: [String: Double] = [:]) {
        self.bookmark = bookmark
        self.failureFirstSeen = failureFirstSeen
    }
}
