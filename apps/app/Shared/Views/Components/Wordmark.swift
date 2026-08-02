import SwiftUI

/// The notifi wordmark: Inconsolata with the final `i`'s tittle replaced by a
/// brand-red dot.
///
/// The last `i` is swapped for a dotless `ı` (U+0131, which Inconsolata ships) and
/// the dot is drawn back as a real circle, so it can take any colour without
/// touching the glyph.
///
/// The geometry is measured off the real font rather than eyeballed — render `i`
/// and `ı`, diff them, and the difference is the tittle:
///
///     advance        0.5   em   (monospace, wdth 100)
///     tittle centre  0.2475 em from the glyph origin
///                    0.615  em above the baseline
///     diameter       0.15  em
///
struct Wordmark: View {
    /// Point size of the type. The dot scales with it.
    var size: CGFloat = 17
    var color: Color = Theme.fg
    var dot: Color = Theme.brand

    private static let text = "notifı"          // dotless final i
    private static let advance: CGFloat = 0.5
    private static let tittleX: CGFloat = 0.2475
    private static let tittleY: CGFloat = 0.615
    private static let tittleD: CGFloat = 0.15

    /// Distance from the leading edge to the centre of the dot.
    private var dotCenterX: CGFloat {
        (Self.advance * CGFloat(Self.text.count - 1) + Self.tittleX) * size
    }

    /// Distance from the text baseline up to the centre of the dot.
    private var dotRise: CGFloat { Self.tittleY * size }

    var body: some View {
        Text(Self.text)
            .font(.custom("Inconsolata", fixedSize: size).weight(.bold))
            .foregroundStyle(color)
            .overlay(alignment: .bottomLeading) {
                // `.bottomLeading` of a Text sits on the descender, not the
                // baseline, so lift by the descent (0.2 em for Inconsolata).
                Circle()
                    .fill(dot)
                    .frame(width: Self.tittleD * size, height: Self.tittleD * size)
                    .offset(
                        x: dotCenterX - (Self.tittleD * size) / 2,
                        y: -(dotRise - (Self.tittleD * size) / 2) - 0.20 * size
                    )
            }
            .fixedSize()
            .accessibilityElement()
            .accessibilityLabel("notifi")
    }
}

/// The bell, with the badge disc picked out in brand red when anything is unread.
///
/// The disc is part of the artwork, so it is drawn white with the rest of the
/// template and a red circle is laid exactly on top. Geometry measured off the
/// asset by flood-filling the disc:
///
///     centre    (0.7028, 0.1667) of the frame
///     diameter  0.331 of the frame
///
/// The overlay is a hair wider than the disc so no white rim survives.
struct BellMark: View {
    var size: CGFloat = 21
    var hasUnread: Bool = false

    /// Bumped on every new-message post; drives the shake.
    @State private var shake = 0

    private static let badgeCentre = CGPoint(x: 0.7028, y: 0.1667)
    private static let badgeDiameter: CGFloat = 0.345

    var body: some View {
        Image("BellLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Theme.fg)
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
            .frame(width: size, height: size)
            // Pivot at the crown, the way a real bell swings.
            .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, angle in
                view.rotationEffect(.degrees(angle), anchor: .top)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-15, duration: 0.08)
                    CubicKeyframe(12, duration: 0.10)
                    CubicKeyframe(-8, duration: 0.10)
                    CubicKeyframe(5, duration: 0.10)
                    CubicKeyframe(-2.5, duration: 0.10)
                    CubicKeyframe(0, duration: 0.10)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .notifiNewMessages)) { _ in
                shake &+= 1
            }
            .animation(.easeOut(duration: 0.2), value: hasUnread)
            .accessibilityHidden(true)
    }
}

/// The bell plus the wordmark — what sits in the top-left of every screen.
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
