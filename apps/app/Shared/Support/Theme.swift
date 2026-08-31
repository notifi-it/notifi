import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum Theme {

    static let bg = grey(light: 0.949, dark: 0.11)
    static let groupFill = grey(light: 1.0, dark: 0.185)
    static let fg = grey(light: 0.102, dark: 0.929)
    static let read = grey(light: 0.28, dark: 0.72)
    static let muted = grey(light: 0.36, dark: 0.631)
    static let dim = grey(light: 0.44, dark: 0.54)
    static let mark = grey(light: 0.63, dark: 0.355)
    static let line = grey(light: 0.878, dark: 0.20)
    static let chip = grey(light: 0.82, dark: 0.235)

    static let controlBorder = grey(light: 0.55, dark: 0.44)
    static let surface = grey(light: 0.945, dark: 0.15)

    static let brand = rgb(light: (0.737, 0.129, 0.133), dark: (0.784, 0.160, 0.165))

    static let brandText = rgb(light: (0.659, 0.114, 0.118), dark: (0.859, 0.290, 0.294))

    static let brandDim = rgb(light: (0.784, 0.365, 0.361), dark: (0.925, 0.596, 0.588))

    static let danger = rgb(light: (0.701, 0.133, 0.149), dark: (0.898, 0.282, 0.302))

    static let chromaWarm = rgb(light: (0.737, 0.129, 0.133), dark: (0.878, 0.196, 0.204))

    static let chromaCool = rgb(light: (0.086, 0.478, 0.545), dark: (0.212, 0.769, 0.847))

    private static func grey(light: Double, dark: Double) -> Color {
        pair(light: (light, light, light), dark: (dark, dark, dark))
    }

    private static func rgb(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        pair(light: light, dark: dark)
    }

    private static func pair(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        #if os(iOS)
        Color(UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #endif
    }

    static let gutter: CGFloat = 20

    #if os(macOS)
    static let chromeRule: CGFloat = 3
    static let chromeRuleColor = fg
    #else
    static let chromeRule: CGFloat = 2
    static let chromeRuleColor = line
    #endif

    static let blockRadius: CGFloat = 10

    static let groupInset: CGFloat = 12

    #if os(iOS)
    static var hairline: CGFloat { 1 / UIScreen.main.scale }
    #else
    static var hairline: CGFloat { 1 / (NSScreen.main?.backingScaleFactor ?? 2) }
    #endif

    #if os(macOS)
    static let firstBlockTop: CGFloat = 10
    #else
    static let firstBlockTop: CGFloat = 0
    #endif

    static let headerBarHeight: CGFloat = 30
    static let headerSubtitleHeight: CGFloat = 22
    static let headerActionSpacing: CGFloat = 8

    static let headerBarGap: CGFloat = 20
    static let rowGap: CGFloat = 13

    static let rowPadV: CGFloat = 12

    static let controlWidth: CGFloat = 88
    static let radius: CGFloat = 6
    static let innerRadius: CGFloat = 3
    static let thumb: CGFloat = 42

    static let minTarget: CGFloat = 44

    static let bottomPlate: CGFloat = 44

    #if os(macOS)
    static let topFade: CGFloat = 36
    #else
    static let topFade: CGFloat = 14
    #endif

    #if os(macOS)
    static let contentTop: CGFloat = firstBlockTop
    static let listContentTop: CGFloat = contentTop
    #else
    static let contentTop: CGFloat = topFade + firstBlockTop
    static let listIntrinsicTopInset: CGFloat = 3
    static let listContentTop: CGFloat = contentTop - listIntrinsicTopInset
    #endif

    static let press = Animation.easeOut(duration: 0.12)

    static let state = Animation.easeOut(duration: 0.2)

    static let reveal = Animation.easeOut(duration: 0.25)

    static var reduceMotion: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    static var title: Font { .inco(.headline, weight: .semibold) }
    static var titleUnread: Font { .inco(.headline, weight: .bold) }
    static var body: Font { .karla(.subheadline) }
    static var meta: Font { .inco(.caption, weight: .medium) }

    static var metaUnread: Font { .inco(.caption, weight: .semibold) }
    static var metaSmall: Font { .inco(.caption2, weight: .regular) }
    static var label: Font { .inco(.caption2, weight: .medium) }
    static var screenTitle: Font { .inco(.title, weight: .semibold) }
    static let screenTitleTracking: CGFloat = 1
    static var sectionLabel: Font { .inco(.caption2, weight: .semibold) }
}

extension View {
    func geistGutter() -> some View { padding(.horizontal, Theme.gutter) }

    func geistBannerTransition() -> some View {
        transition(Theme.reduceMotion
                   ? .opacity
                   : .opacity.combined(with: .move(edge: .top)))
    }

    func geistHitArea(expandedBy pad: CGFloat) -> some View {
        contentShape(.interaction, Rectangle().inset(by: -pad))
    }

    func geistPageHeader() -> some View {
        #if os(macOS)
        padding(.top, 18).padding(.bottom, 0)
        #else
        padding(.top, 4).padding(.bottom, 2)
        #endif
    }

    func geistConsequence() -> some View {
        font(Theme.body)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    func geistTopFade() -> some View {
        #if os(macOS)
        modifier(ScrolledTopFade())
        #else
        overlay(alignment: .top) { GroundFade() }
        #endif
    }
}

#if os(macOS)
struct ScrolledTopFade: ViewModifier {
    @State private var scrolled = false

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top > 0.5
                } action: { _, isScrolled in
                    scrolled = isScrolled
                }
                .overlay(alignment: .top) {
                    GroundFade()
                        .opacity(scrolled ? 1 : 0)
                        .animation(.easeOut(duration: 0.15), value: scrolled)
                }
        } else {
            content
        }
    }
}
#endif

struct GroundFade: View {
    var body: some View {
        StaticField()
            .frame(height: Theme.topFade)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.12), location: 0.45),
                        .init(color: .white.opacity(0.55), location: 0.75),
                        .init(color: .white, location: 1)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct GeistPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration)
    }

    private struct PressBody: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration

        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.96)
                .opacity(reduceMotion && configuration.isPressed ? 0.6 : 1)
                .animation(Theme.press, value: configuration.isPressed)
        }
    }
}

struct GeistRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(Theme.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GeistPressStyle {
    static var geist: GeistPressStyle { GeistPressStyle() }
}

extension ButtonStyle where Self == GeistRowStyle {
    static var geistRow: GeistRowStyle { GeistRowStyle() }
}

extension View {
    func bellSwing(trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, angle in
            view.rotationEffect(.degrees(angle), anchor: .top)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-20, duration: 0.11)
                CubicKeyframe(18, duration: 0.225)
                CubicKeyframe(-16, duration: 0.225)
                CubicKeyframe(14, duration: 0.225)
                CubicKeyframe(-13, duration: 0.225)
                CubicKeyframe(12, duration: 0.225)
                CubicKeyframe(-10, duration: 0.225)
                CubicKeyframe(8, duration: 0.225)
                CubicKeyframe(-6, duration: 0.225)
                CubicKeyframe(4, duration: 0.225)
                CubicKeyframe(-2, duration: 0.225)
                CubicKeyframe(0, duration: 0.225)
            }
        }
    }

    func clapperSwing(trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, angle in
            view.rotationEffect(.degrees(angle), anchor: .top)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0, duration: 0.06)
                CubicKeyframe(-30, duration: 0.11)
                CubicKeyframe(27, duration: 0.225)
                CubicKeyframe(-24, duration: 0.225)
                CubicKeyframe(20, duration: 0.225)
                CubicKeyframe(-18, duration: 0.225)
                CubicKeyframe(15, duration: 0.225)
                CubicKeyframe(-12, duration: 0.225)
                CubicKeyframe(9, duration: 0.225)
                CubicKeyframe(-6, duration: 0.225)
                CubicKeyframe(3, duration: 0.225)
                CubicKeyframe(0, duration: 0.225)
            }
        }
    }

    func grainGlyph(active: Bool = true, cell: CGFloat = 3, shiftScale: CGFloat = 1) -> some View {
        modifier(GrainGlyph(active: active, cell: cell, shiftScale: shiftScale))
    }

    func grainBurst(on active: Bool, cell: CGFloat = 3, shiftScale: CGFloat = 1, duration: TimeInterval = 0.65) -> some View {
        modifier(GrainBurst(active: active, cell: cell, shiftScale: shiftScale, duration: duration))
    }
}

struct GrainGlyph: ViewModifier {
    var active: Bool
    var cell: CGFloat
    var shiftScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if active && !reduceMotion {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let shift = Self.chromaShift(at: time) * shiftScale
                GrainFrame(shift: shift, time: time, cell: cell, strength: 1) { content }
                    .opacity(Self.glow(at: time))
            }
        } else {
            content
        }
    }

    private static func chromaShift(at time: TimeInterval) -> CGFloat {
        var generator = SeededGenerator(seed: (time * 11).rounded(.down))
        guard Double.random(in: 0...1, using: &generator) < 0.22 else { return 0 }
        return CGFloat(Double.random(in: 0.8...3.2, using: &generator))
    }

    private static func glow(at time: TimeInterval) -> Double {
        var episode = SeededGenerator(seed: (time * 1.7).rounded(.down))
        guard Double.random(in: 0...1, using: &episode) < 0.13 else { return 1 }
        var pulse = SeededGenerator(seed: (time * 18).rounded(.down))
        guard Double.random(in: 0...1, using: &pulse) < 0.4 else { return 1 }
        return Double.random(in: 0.35...0.62, using: &pulse)
    }
}

struct GrainBurst: ViewModifier {
    var active: Bool
    var cell: CGFloat
    var shiftScale: CGFloat
    var duration: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burstEnds: Date?

    @ViewBuilder
    func body(content: Content) -> some View {
        Group {
            if let burstEnds {
                TimelineView(.animation) { context in
                    let remaining = burstEnds.timeIntervalSince(context.date)
                    let intensity = pow(max(0, min(1, remaining / duration)), 2)
                    let time = context.date.timeIntervalSinceReferenceDate
                    let shift = Self.chromaShift(at: time, intensity: intensity) * shiftScale
                    GrainFrame(shift: shift, time: time, cell: cell, strength: intensity) { content }
                        .opacity(Self.glow(at: time, intensity: intensity))
                }
                .task(id: burstEnds) {
                    try? await Task.sleep(for: .seconds(max(0, burstEnds.timeIntervalSinceNow)))
                    self.burstEnds = nil
                }
            } else {
                content
            }
        }
        .onChange(of: active) { _, hovering in
            guard hovering, !reduceMotion else { return }
            burstEnds = Date(timeIntervalSinceNow: duration)
        }
    }

    private static func chromaShift(at time: TimeInterval, intensity: Double) -> CGFloat {
        guard intensity > 0 else { return 0 }
        var generator = SeededGenerator(seed: (time * 11).rounded(.down))
        guard Double.random(in: 0...1, using: &generator) < 0.15 + 0.85 * intensity else { return 0 }
        return CGFloat(Double.random(in: 0.8...3.2, using: &generator) * intensity)
    }

    private static func glow(at time: TimeInterval, intensity: Double) -> Double {
        guard intensity > 0 else { return 1 }
        var pulse = SeededGenerator(seed: (time * 18).rounded(.down))
        guard Double.random(in: 0...1, using: &pulse) < 0.45 * intensity else { return 1 }
        return 1 - Double.random(in: 0.38...0.65, using: &pulse) * intensity
    }
}

private struct GrainFrame<Glyph: View>: View {
    let shift: CGFloat
    let time: TimeInterval
    let cell: CGFloat
    let strength: Double
    @ViewBuilder let glyph: Glyph

    var body: some View {
        ZStack {
            if shift > 0 {
                glyph
                    .overlay { Theme.chromaWarm }
                    .mask(glyph)
                    .offset(x: -shift)
                glyph
                    .overlay { Theme.chromaCool }
                    .mask(glyph)
                    .offset(x: shift)
            }

            glyph
                .overlay { grain }
                .mask(glyph)
        }
    }

    private var grain: some View {
        Canvas { canvasContext, size in
            var generator = SeededGenerator(seed: time)
            let columns = Int(size.width / cell) + 1
            let rows = Int(size.height / cell) + 1
            for row in 0..<rows {
                for column in 0..<columns {
                    guard Double.random(in: 0...1, using: &generator) < 0.5 else { continue }
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    let brightness = Double.random(in: 0...1, using: &generator)
                    canvasContext.fill(Path(rect), with: .color(.white.opacity(brightness * 0.35 * strength)))
                }
            }
        }
        .blendMode(.overlay)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: TimeInterval) {
        state = UInt64(bitPattern: Int64(seed * 1000)) &* 2862933555777941757 &+ 1
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

struct Hairline: View {
    var color: Color = Theme.line
    var weight: CGFloat = Theme.hairline
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: weight)
            .accessibilityHidden(true)
    }
}
