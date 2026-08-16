import SwiftUI

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
            .offset(x: sin(progress * 150) * pow(1 - progress, 1.5) * 5 * strength)
    }
}

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
    func grainReveal(trigger: AnyHashable = 0, duration: Double = 0.35,
                     once: Bool = false, strength: Double = 1) -> some View {
        modifier(GrainReveal(trigger: trigger, duration: duration, once: once,
                             strength: strength))
    }
}
