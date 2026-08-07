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
    /// The tile is drawn at the panel's own scale so one noise pixel is one
    /// device pixel. At a fixed scale of 1 each pixel became three on a 3x
    /// screen, which is coarse enough to read as fabric rather than static.
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // Still frame under Reduce Motion. The crawl is the whole effect, so
        // there is nothing to degrade gracefully to — it simply stops.
        if reduceMotion {
            tile(StaticNoise.frames[0])
        } else {
            TimelineView(.periodic(from: .now, by: StaticNoise.frameDuration)) { context in
                tile(StaticNoise.frames[StaticNoise.index(at: context.date)])
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

    /// The ground, matching `Theme.bg` (#1C1C1C), and how far the speckle
    /// travels either side of it. See the note on `StaticField`.
    private static let ground: Double = 0.11
    private static let amplitude: Double = 0.055

    @MainActor static let frames: [CGImage] = (0..<6).compactMap { _ in makeTile() }

    static func index(at date: Date) -> Int {
        let tick = Int(date.timeIntervalSinceReferenceDate / frameDuration)
        // `%` on a negative tick would trap on the array subscript. Dates before
        // the reference date are not reachable here, but the cost of not
        // relying on that is one call.
        return abs(tick) % frames.count
    }

    private static func makeTile() -> CGImage? {
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
