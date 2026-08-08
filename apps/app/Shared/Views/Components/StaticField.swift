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
    /// How far off the ground this patch of static sits.
    ///
    /// The step is in the grain's own ground rather than a flat fill laid over
    /// it: a translucent panel on top of the static dilutes the speckle it
    /// covers, so a raised block reads as *less* textured than the screen around
    /// it — the opposite of the thing it is meant to be a piece of. Shifting the
    /// ground the tile is generated at keeps the texture at full strength and
    /// moves only where it sits.
    enum Level { case ground, raised, hover }

    var level: Level = .ground
    /// Only the screen's own backdrop reaches under the safe area. A patch
    /// filling a row is bounded by the row.
    var fillsScreen = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    /// The tile is drawn at the panel's own scale so one noise pixel is one
    /// device pixel. At a fixed scale of 1 each pixel became three on a 3x
    /// screen, which is coarse enough to read as fabric rather than static.
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // Still frame under Reduce Motion. The crawl is the whole effect, so
        // there is nothing to degrade gracefully to — it simply stops.
        let frames = StaticNoise.frames(for: colorScheme, level: level)
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
            .ignoresSafeArea(edges: fillsScreen ? .all : [])
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
    /// anything at all. At ±0.035 the range is #EFEFEF–#FFFFFF, which puts `dim`
    /// at roughly 4.4:1 over the darkest speckle — under the 4.5:1 floor the dark
    /// tile stops at, and a deliberate exception rather than an oversight.
    private static let darkGround: Double = 0.11
    private static let darkAmplitude: Double = 0.055
    private static let lightGround: Double = 0.98
    private static let lightAmplitude: Double = 0.035

    /// What a raised patch adds to the ground it sits on.
    ///
    /// Light steps *down* where dark steps up, the same direction `Theme.surface`
    /// moves in and for the same reason: which way reads as nearer depends on
    /// where the light is coming from.
    private static let darkStep: Double = 0.04
    private static let lightStep: Double = -0.028

    static let frameCount = 6

    /// Keyed rather than six stored properties, so a level nothing draws is never
    /// generated — the hover tiles cost nothing on a screen with no pointer.
    private static var cache: [String: [CGImage]] = [:]

    static func frames(for scheme: ColorScheme, level: StaticField.Level) -> [CGImage] {
        let dark = scheme == .dark
        let key = "\(dark)-\(level)"
        if let hit = cache[key] { return hit }
        let step = dark ? darkStep : lightStep
        let base = dark ? darkGround : lightGround
        let ground: Double
        switch level {
        case .ground: ground = base
        case .raised: ground = base + step
        case .hover: ground = base + step * 2
        }
        let made = (0..<frameCount).compactMap { _ in
            makeTile(ground: ground, amplitude: dark ? darkAmplitude : lightAmplitude)
        }
        cache[key] = made
        return made
    }

    static func index(at date: Date) -> Int {
        let tick = Int(date.timeIntervalSinceReferenceDate / frameDuration)
        // `%` on a negative tick would trap on the array subscript. Dates before
        // the reference date are not reachable here, but the cost of not
        // relying on that is one call.
        // Every set is the same length by construction, so the index does not
        // depend on which one is being drawn — and the crawl does not restart
        // when the appearance changes under it, or when a row is hovered.
        return abs(tick) % frameCount
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
