import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
enum Clipboard {
    static func copy(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
        // Confirmation lives here rather than at the call sites. Some of them
        // flash "Copied" on their own button and some — the feed's context
        // menu — change nothing on screen at all, and those were exactly the
        // ones saying nothing to VoiceOver either. A copy that cannot be seen
        // or felt is indistinguishable from a menu item that did nothing.
        Haptics.tap()
        AccessibilityNotification.Announcement(Copy.Common.copied).post()
    }

    /// For send keys and commands that embed one. An ordinary copy syncs through
    /// Universal Clipboard to every nearby device and sits until something
    /// overwrites it; a secret gets neither of those defaults.
    static func copySensitive(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.setItems(
            [["public.utf8-plain-text": string]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(60),
            ]
        )
        #else
        // macOS has no expiry, but the concealed marker keeps clipboard managers
        // from persisting the value, and org.nspasteboard.TransientType keeps it
        // out of their history entirely.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        #endif
        Haptics.tap()
        AccessibilityNotification.Announcement(Copy.Common.copied).post()
    }
}
