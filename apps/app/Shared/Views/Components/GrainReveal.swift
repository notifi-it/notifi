import SwiftUI

/// Tunes a view in like a channel locking on: its pixels start as static and
/// sharpen into place, the same grain `StaticField` draws but confined to the
/// view's own alpha. Drives `GrainReveal.metal`.
///
/// The modifier is `Animatable` so the shader sees every intermediate
/// progress value; a plain `@State` flip would jump it from grain to solid
/// in one frame.
private struct GrainRevealEffect: ViewModifier, Animatable {
    var progress: Double
    var strength: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .colorEffect(ShaderLibrary.grainReveal(.float(Float(progress))))
            .blur(radius: (1 - progress) * 1.5 * strength)
            .offset(x: sin(progress * 110) * (1 - progress) * 2)
    }
}

/// Triggers a view has already revealed this session. List rows lose their
/// `@State` when scrolled far enough off screen, so per-view state cannot
/// remember that a row has played; without this, every scroll back replays it.
@MainActor
private enum GrainRevealLedger {
    static var seen: Set<AnyHashable> = []
}

private struct GrainReveal: ViewModifier {
    var trigger: AnyHashable
    var duration: Double
    var once: Bool
    var strength: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .modifier(GrainRevealEffect(progress: progress, strength: strength))
                .onAppear { play() }
                .onChange(of: trigger) { play() }
        }
    }

    private func play() {
        if once && GrainRevealLedger.seen.contains(trigger) {
            progress = 1
            return
        }
        GrainRevealLedger.seen.insert(trigger)
        progress = 0
        withAnimation(.easeOut(duration: duration)) { progress = 1 }
    }
}

extension View {
    /// Runs on appear and again whenever `trigger` changes. With `once`, a
    /// given trigger plays a single time per app session, so scrolling a row
    /// back into view shows it already settled.
    /// `strength` scales how far the view starts from legible: 1 is the
    /// default tune-in, higher starts blurrier and dimmer.
    func grainReveal(trigger: AnyHashable = 0, duration: Double = 0.35,
                     once: Bool = false, strength: Double = 1) -> some View {
        modifier(GrainReveal(trigger: trigger, duration: duration, once: once,
                             strength: strength))
    }
}
