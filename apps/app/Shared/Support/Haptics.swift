#if os(iOS)
import UIKit
#endif

/// The app's whole haptic vocabulary, so a copy in the feed and a copy on a key
/// detail cannot drift onto different sensations.
///
/// Feedback marks outcomes, never touches: the system already clicks the
/// controls that should click, and what it cannot know is when an action lands
/// — a value on the clipboard, a key created, a request failed. Imperative
/// rather than `.sensoryFeedback`, because most of those moments happen inside
/// action closures and leave no state a view modifier could watch.
///
/// Every call is a no-op on macOS. The trackpad's haptics belong to the system
/// (alignment, force click), and a menu bar app buzzing the pointer would be
/// noise from a place feedback is not expected.
@MainActor
enum Haptics {
    /// A control moved between its states: a tab, a switch.
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// A small action landed: copied, marked read.
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// A request the reader waited on came back well.
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// The same request came back badly. Only ever fired alongside visible
    /// error copy — the buzz says look, the words say what.
    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
