import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var serverID: Int
    var title: String
    var body: String?
    var link: URL?
    var imageURL: URL?
    var keyID: Int?
    var createdAt: Date
    /// When the event actually happened, if the sender said so. Millisecond
    /// precision, unlike `createdAt`, which the server records in whole seconds.
    /// Never used for sorting — see the 0003 migration for why.
    var occurredAt: Date?
    var isRead: Bool = false

    init(
        serverID: Int,
        title: String,
        body: String? = nil,
        link: URL? = nil,
        imageURL: URL? = nil,
        keyID: Int? = nil,
        createdAt: Date,
        occurredAt: Date? = nil,
        isRead: Bool = false
    ) {
        self.serverID = serverID
        self.title = title
        self.body = body
        self.link = link
        self.imageURL = imageURL
        self.keyID = keyID
        self.createdAt = createdAt
        self.occurredAt = occurredAt
        self.isRead = isRead
    }
}
