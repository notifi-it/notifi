import SwiftUI

struct Wordmark: View {
    var size: CGFloat = 17
    var color: Color = Theme.fg
    var dot: Color = Theme.brand

    private static let aspect: CGFloat = 3450.0 / 1000.0
    private static let tittleX: CGFloat = 0.9182
    private static let tittleY: CGFloat = 0.0858
    private static let tittleD: CGFloat = 0.1543

    private var width: CGFloat { size * Self.aspect }
    private var dotSize: CGFloat { Self.tittleD * size }

    var body: some View {
        Image("WordmarkLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: width, height: size)
            .overlay {
                Circle()
                    .fill(dot)
                    .frame(width: dotSize, height: dotSize)
                    .position(x: Self.tittleX * width, y: Self.tittleY * size)
            }
            .frame(width: width, height: size)
            .accessibilityElement()
            .accessibilityLabel(Copy.Components.wordmark)
    }
}

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

struct BrandMark: View {
    var size: CGFloat = 17
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 9) {
            BellMark(size: size * 1.25, hasUnread: model.hasUnread)
            Wordmark(size: size)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        Wordmark(size: 17)
        Wordmark(size: 28)
        Wordmark(size: 44)
    }
    .padding(40)
    .background(Theme.bg)
}
