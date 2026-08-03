#if os(macOS)
import SwiftUI

/// The macOS tab bar.
///
/// iOS gets this from `TabView`; macOS cannot. SwiftUI's `TabView` renders as a
/// segmented control at the *top* on macOS, which is the system look rather than
/// this one, and there is no tab bar inside a popover at all. So it is drawn
/// here: same three destinations as iOS, same icons, in Geist.
///
/// Hover is a Mac affordance with no iOS equivalent, so it is additive — the
/// selected/unselected treatment matches iOS exactly and hover only lifts an
/// unselected item toward the selected colour.
struct GeistTabBar: View {
    @Binding var selection: AppTab

    private struct Item {
        let tab: AppTab
        let title: String
        let icon: String
    }

    private let items: [Item] = [
        Item(tab: .inbox, title: "Notifications", icon: "akar-inbox"),
        Item(tab: .keys, title: "Keys", icon: "akar-key"),
        Item(tab: .settings, title: "Settings", icon: "akar-gear")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                ForEach(items, id: \.tab) { item in
                    TabButton(
                        title: item.title,
                        icon: item.icon,
                        isSelected: selection == item.tab
                    ) {
                        selection = item.tab
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(Theme.bg)
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    private var tint: Color {
        if isSelected { return Theme.fg }
        return hovering ? Theme.muted : Theme.dim
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.inco(.caption2, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
#endif
