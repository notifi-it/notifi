import SwiftUI
import CoreGraphics

/// The ground, with television static crawling over it.
///
/// Greys only — this sits under every screen in the app, so it has to stay a
/// texture rather than becoming a pattern anyone reads.
///
/// The amplitude is the whole argument. `dim` — the app's lowest-contrast text,
/// carrying every explanatory paragraph including the ones about losing a
/// device — measures 4.75:1 on a flat ground, only 0.25 above the 4.5:1 floor.
/// The grain spends that margin: at ±0.055 the darkest speckle is #101010 and
/// the lightest #292929, which moves `dim` to roughly 4.5:1 at worst. That is
/// at the line, not past it, and it is where this stops. Anything wider is a
/// legibility regression wearing a texture.
struct StaticField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    /// The tile is drawn at the panel's own scale so one noise pixel is one
    /// device pixel. At a fixed scale of 1 each pixel became three on a 3x
    /// screen, which is coarse enough to read as fabric rather than static.
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // Still frame under Reduce Motion. The crawl is the whole effect, so
        // there is nothing to degrade gracefully to — it simply stops.
        let frames = StaticNoise.frames(for: colorScheme)
        if reduceMotion {
            tile(frames[0])
        } else {
            TimelineView(.periodic(from: .now, by: StaticNoise.frameDuration)) { context in
                tile(frames[StaticNoise.index(at: context.date)])
            }
        }
    }

    private func tile(_ image: CGImage) -> some View {
        Image(decorative: image, scale: displayScale)
            .resizable(resizingMode: .tile)
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// The pre-rendered noise itself.
///
/// Six tiles are baked once and cycled, rather than generating a frame per
/// draw. Real static never repeats, but at 12fps and this amplitude the loop is
/// invisible, and generating 65k pixels twelve times a second is not a cost
/// worth paying for a background nobody looks at directly.
@MainActor
private enum StaticNoise {
    /// 12fps. Faster reads as a strobe; slower stops looking like a signal and
    /// starts looking like the screen redrawing.
    static let frameDuration: TimeInterval = 1.0 / 12.0

    /// Tile edge, in device pixels. Larger than it needs to be for coverage:
    /// at one-pixel grain the tile is only ~170pt across on a 3x screen, and
    /// below this the repeat starts to read as a pattern.
    private static let size = 512

    /// The ground, matching `Theme.bg`, and how far the speckle travels either
    /// side of it. See the note on `StaticField`.
    ///
    /// The light amplitude is a third of the dark one and is not a taste
    /// decision: `dim` sits at 4.65:1 on the light ground against 4.75:1 on the
    /// dark, so there is less margin to spend, and the eye reads a dark speckle
    /// on paper as dirt long before it reads a light speckle on charcoal as
    /// anything at all. At ±0.018 the range is #F5F5F5–#FEFEFE, which holds
    /// `dim` at 4.5:1 at worst — the same floor the dark tile stops at.
    private static let darkGround: Double = 0.11
    private static let darkAmplitude: Double = 0.055
    private static let lightGround: Double = 0.98
    private static let lightAmplitude: Double = 0.018

    private static let darkFrames: [CGImage] =
        (0..<6).compactMap { _ in makeTile(ground: darkGround, amplitude: darkAmplitude) }
    private static let lightFrames: [CGImage] =
        (0..<6).compactMap { _ in makeTile(ground: lightGround, amplitude: lightAmplitude) }

    static func frames(for scheme: ColorScheme) -> [CGImage] {
        scheme == .dark ? darkFrames : lightFrames
    }

    static func index(at date: Date) -> Int {
        let tick = Int(date.timeIntervalSinceReferenceDate / frameDuration)
        // `%` on a negative tick would trap on the array subscript. Dates before
        // the reference date are not reachable here, but the cost of not
        // relying on that is one call.
        // Both sets are the same length by construction, so the index does not
        // depend on which one is being drawn — and the crawl does not restart
        // when the appearance changes under it.
        return abs(tick) % darkFrames.count
    }

    private static func makeTile(ground: Double, amplitude: Double) -> CGImage? {
        // One independent sample per pixel. An earlier version averaged each
        // sample with its neighbours to stop square clumps reading as a grid,
        // which mattered when a sample covered a block of pixels; at this grain
        // the averaging only blurs the thing it is meant to sharpen.
        var pixels = [UInt8](repeating: 0, count: size * size)
        for i in pixels.indices {
            let level = ground + (Double.random(in: 0...1) - 0.5) * 2 * amplitude
            pixels[i] = UInt8(clamping: Int((level * 255).rounded()))
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
