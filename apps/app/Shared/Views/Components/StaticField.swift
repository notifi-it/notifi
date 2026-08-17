import SwiftUI
import CoreGraphics

struct StaticField: View {
    enum Level { case ground, raised, hover }

    var level: Level = .ground
    var fillsScreen = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
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

@MainActor
private enum StaticNoise {
    static let frameDuration: TimeInterval = 1.0 / 12.0

    private static let size = 512

    private static let darkGround: Double = 0.11
    private static let darkAmplitude: Double = 0.055
    private static let lightGround: Double = 0.949
    private static let lightAmplitude: Double = 0.035

    private static let darkStep: Double = 0.075
    private static let lightStep: Double = 0.051

    static let frameCount = 6

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
        return abs(tick) % frameCount
    }

    private static func makeTile(ground: Double, amplitude: Double) -> CGImage? {
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
