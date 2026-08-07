import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private final class Delivery: @unchecked Sendable {
        let handler: (UNNotificationContent) -> Void
        let content: UNMutableNotificationContent
        private let lock = NSLock()
        private var delivered = false

        init(handler: @escaping (UNNotificationContent) -> Void, content: UNMutableNotificationContent) {
            self.handler = handler
            self.content = content
        }

        func finish() {
            lock.lock()
            let alreadyDelivered = delivered
            delivered = true
            lock.unlock()
            guard !alreadyDelivered else { return }
            handler(content)
        }

        func withContent(_ body: (UNMutableNotificationContent) -> Void) {
            lock.lock()
            defer { lock.unlock() }
            guard !delivered else { return }
            body(content)
        }
    }

    private var delivery: Delivery?

    private static let maxImageBytes: Int64 = 5 * 1024 * 1024
    private static let allowedTypes: Set<String> = ["image/png", "image/jpeg", "image/gif"]

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let best = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        let delivery = Delivery(handler: contentHandler, content: best)
        self.delivery = delivery

        best.title = Copy.Push.fallbackTitle
        best.body = Copy.Push.fallbackBody

        guard let notifi = request.content.userInfo["notifi"] as? [String: Any],
              let sealed = notifi["sealed"] as? String,
              let opener = try? DeviceIdentity.loadOpener(),
              let plaintext = try? opener.open(sealedB64: sealed, info: "content"),
              let content = try? JSONDecoder().decode(MessageContent.self, from: plaintext)
        else { delivery.finish(); return }

        best.title = content.title
        if let message = content.message { best.body = message }
        best.categoryIdentifier = Self.category(for: content)

        // Downloading here would happen on arrival, before the user has seen
        // anything, so the sender would learn the device's IP address and the
        // exact delivery time from a message that was never opened.
        guard RemoteImages.isEnabled,
              let image = content.image,
              let url = URL(string: image),
              url.scheme == "https" else {
            delivery.finish()
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { tmp, response, _ in
            defer { delivery.finish() }
            guard let tmp,
                  let http = response as? HTTPURLResponse,
                  let mime = http.mimeType?.lowercased(),
                  Self.allowedTypes.contains(mime),
                  http.expectedContentLength <= Self.maxImageBytes else {
                return
            }

            let attributes = try? FileManager.default.attributesOfItem(atPath: tmp.path)
            if let size = attributes?[.size] as? Int64, size > Self.maxImageBytes {
                return
            }

            let ext: String
            switch mime {
            case "image/png": ext = "png"
            case "image/gif": ext = "gif"
            default: ext = "jpg"
            }

            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            do {
                try FileManager.default.moveItem(at: tmp, to: dest)
            } catch {
                return
            }
            if let attachment = try? UNNotificationAttachment(identifier: "image", url: dest) {
                delivery.withContent { $0.attachments = [attachment] }
            }
        }
        task.resume()
    }

    /// A message whose blob would not open gets no category at all: the buttons
    /// would act on a link this side never read.
    private static func category(for content: MessageContent) -> String {
        var hasLink = false
        if let link = content.link, let url = URL(string: link) {
            hasLink = LinkPolicy.allows(url, anyScheme: false)
        }
        return NotificationCategories.categoryID(keyID: content.keyID, hasLink: hasLink)
    }

    override func serviceExtensionTimeWillExpire() {
        delivery?.finish()
    }
}
