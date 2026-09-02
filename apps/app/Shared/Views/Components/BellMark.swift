import SwiftUI

struct BellMark: View {
    var size: CGFloat = 21
    var hasUnread: Bool = false

    @State private var shake = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let badgeCentre = CGPoint(x: 0.7006, y: 0.1498)
    private static let badgeDiameter: CGFloat = 0.2835

    var body: some View {
        ZStack {
            Image("BellLogoBody")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .overlay {
                    if hasUnread {
                        Circle()
                            .fill(Theme.brand)
                            .frame(width: size * Self.badgeDiameter,
                                   height: size * Self.badgeDiameter)
                            .position(x: size * Self.badgeCentre.x,
                                      y: size * Self.badgeCentre.y)
                    }
                }
                .bellSwing(trigger: shake)
            Image("BellLogoClapper")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clapperSwing(trigger: shake)
        }
            .foregroundStyle(Theme.fg)
            .frame(width: size, height: size)
            .onReceive(NotificationCenter.default.publisher(for: .notifiNewMessages)) { _ in
                guard !reduceMotion else { return }
                shake &+= 1
            }
            .animation(.easeOut(duration: 0.2), value: hasUnread)
            .accessibilityHidden(true)
    }
}
