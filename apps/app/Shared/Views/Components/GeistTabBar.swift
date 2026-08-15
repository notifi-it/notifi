#if os(macOS)
import SwiftUI

struct GeistTabBar: View {
    @Binding var selection: AppTab
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shake = 0

    private struct Item {
        let tab: AppTab
        let title: String
        let icon: String
        var templated = true
        var clapper: String?
    }

    private var items: [Item] {
        [
            Item(tab: .inbox, title: Copy.Tabs.notifications,
                 icon: model.hasUnread ? "BellTabUnreadBody" : "BellTabBody",
                 templated: !model.hasUnread,
                 clapper: "BellTabClapper"),
            Item(tab: .keys, title: Copy.Tabs.keys, icon: "akar-key"),
            Item(tab: .settings, title: Copy.Tabs.settings, icon: "akar-gear")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Hairline(color: Theme.chromeRuleColor, weight: Theme.chromeRule)
            HStack(spacing: 0) {
                ForEach(items, id: \.tab) { item in
                    TabButton(
                        title: item.title,
                        icon: item.icon,
                        templated: item.templated,
                        isSelected: selection == item.tab,
                        shake: item.tab == .inbox ? shake : 0,
                        clapper: item.clapper
                    ) {
                        selection = item.tab
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(Theme.bg)
        .onReceive(NotificationCenter.default.publisher(for: .notifiNewMessages)) { _ in
            guard !reduceMotion else { return }
            shake &+= 1
        }
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    let templated: Bool
    let isSelected: Bool
    var shake = 0
    var clapper: String?
    let action: () -> Void

    @State private var hovering = false

    private var tint: Color {
        if isSelected { return Theme.fg }
        return hovering ? Theme.muted : Theme.dim
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(icon)
                    .renderingMode(templated ? .template : .original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .bellSwing(trigger: shake)
                if let clapper {
                    Image(clapper)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(templated ? tint : Theme.fg)
                        .clapperSwing(trigger: shake)
                }
            }
                .padding(.vertical, 4)
                .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
#endif
