import Foundation

/// In-process signals.
///
/// These used to live inside `MacMenuBar.swift`, which is wrapped in
/// `#if os(macOS)`, so iOS had no way to know a message had arrived. They are
/// shared now — the menu-bar bell and the in-app bell both react to the same post.
extension Notification.Name {
    /// Posted after a sync that brought in at least one new message.
    static let notifiNewMessages = Notification.Name("notifi.newMessages")

    /// Posted when the unread count changes for any reason.
    static let notifiUnreadChanged = Notification.Name("notifi.unreadChanged")

    /// Asks the macOS menu-bar popover to open.
    static let notifiOpenPanel = Notification.Name("notifi.openPanel")

    /// Posted when the socket connects or disconnects.
    static let notifiConnectivityChanged = Notification.Name("notifi.connectivityChanged")
}
