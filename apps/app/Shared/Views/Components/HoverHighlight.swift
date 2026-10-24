import SwiftUI

struct HoverHighlight: ViewModifier {
    var onChange: ((Bool) -> Void)? = nil

    @State private var isHovered = false

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .background {
                if isHovered {
                    StaticField(level: .hover, fillsScreen: false)
                }
            }
            .onHover { hovering in
                isHovered = hovering
                onChange?(hovering)
            }
        #else
        content
        #endif
    }
}

extension View {
    func hoverHighlight(onChange: ((Bool) -> Void)? = nil) -> some View {
        modifier(HoverHighlight(onChange: onChange))
    }
}
