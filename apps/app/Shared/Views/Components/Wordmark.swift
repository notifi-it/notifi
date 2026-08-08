import SwiftUI

/// The notifi wordmark, with the final `i`'s tittle picked out in brand red.
///
/// Drawn from WordmarkLogo rather than set in Inconsolata, so the app and the
/// site show the same mark: the asset carries the same outlines the site serves
/// from apps/api/public/wordmark.svg, JetBrains Mono 700 at -0.03em. Setting it
/// live in the app's body face left the two visibly different words.
///
/// The glyphs are a template and the tittle is laid on top as a real circle, so
/// each takes its own colour. Measured off the source, as fractions of the
/// asset's 3450 × 1000 box:
///
///     tittle centre  0.9182 of the width
///                    0.0858 of the height
///     diameter       0.1543 of the height
///
struct Wordmark: View {
    /// Height of the em box, in points. The mark scales with it.
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

/// The bell, with the badge disc picked out in brand red when anything is unread.
///
/// The disc is part of the artwork, so it is drawn white with the rest of the
/// template and a red circle is laid exactly on top. Geometry measured off the
/// asset by flood-filling the disc:
///
///     centre    (0.7006, 0.1498) of the frame
///     diameter  0.270 of the frame
///
/// The overlay is a hair wider than the disc so no white rim survives. All three
/// are fractions of BellLogo's viewBox — redraw that, or reframe it, and they
/// have to be re-measured.
struct BellMark: View {
    var size: CGFloat = 21
    var hasUnread: Bool = false

    /// Bumped on every new-message post; drives the shake.
    @State private var shake = 0

    /// The shake is triggered by an inbound push rather than by anything the
    /// reader did, which is the case Reduce Motion exists for: it arrives with no
    /// warning and there is nothing to brace against. The badge still turns red,
    /// so the unread state is never carried by the movement alone.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let badgeCentre = CGPoint(x: 0.7006, y: 0.1498)
    /// Sized to the badge drawn in BellLogo, plus a hair so the red fully covers
    /// it. Shrinking the badge in the artwork means shrinking this to match, or
    /// the unread dot overhangs the gap the bell cuts around it.
    private static let badgeDiameter: CGFloat = 0.2835

    var body: some View {
        // Body and clapper as separate layers so the clapper can trail the
        // swing. Same generated box, so stacking them is the whole alignment.
        ZStack {
            // The unread dot rides the body — it sits on the bell's shoulder,
            // so it must take the body's swing, not the clapper's.
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
