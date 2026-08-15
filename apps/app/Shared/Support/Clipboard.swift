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
        Haptics.tap()
        AccessibilityNotification.Announcement(Copy.Common.copied).post()
    }

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
