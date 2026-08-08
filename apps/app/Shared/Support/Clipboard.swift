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
}
