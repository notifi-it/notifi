import SwiftUI

struct HoverHighlight: ViewModifier {
    var onChange: ((Bool) -> Void)? = nil

    @State private var isHovered = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .background {
                if isHovered {
                    StaticField(level: .hover, fillsScreen: false)
                }
            }
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                hoverTask?.cancel()
                guard hovering else {
                    set(false)
                    return
                }
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return }
                    set(true)
                }
            }
        #else
        content
        #endif
    }

    private func set(_ hovering: Bool) {
        isHovered = hovering
        onChange?(hovering)
    }
}

extension View {
    func hoverHighlight(onChange: ((Bool) -> Void)? = nil) -> some View {
        modifier(HoverHighlight(onChange: onChange))
    }
}
