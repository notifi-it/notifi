#if os(iOS)
import UIKit
#endif

@MainActor
enum Haptics {
    #if os(iOS)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    #endif

    static func prepare() {
        #if os(iOS)
        selectionGenerator.prepare()
        impactGenerator.prepare()
        notificationGenerator.prepare()
        #endif
    }

    static func selection() {
        #if os(iOS)
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
        #endif
    }

    static func tap() {
        #if os(iOS)
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
        #endif
    }

    static func success() {
        #if os(iOS)
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
        #endif
    }

    static func error() {
        #if os(iOS)
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
        #endif
    }
}
