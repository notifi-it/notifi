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
    var isRead: Bool = false

    init(
        serverID: Int,
        title: String,
        body: String? = nil,
        link: URL? = nil,
        imageURL: URL? = nil,
        keyID: Int? = nil,
        createdAt: Date,
        isRead: Bool = false
    ) {
        self.serverID = serverID
        self.title = title
        self.body = body
        self.link = link
        self.imageURL = imageURL
        self.keyID = keyID
        self.createdAt = createdAt
        self.isRead = isRead
    }
}
