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
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Counts arrivals so the bell rings once per batch of new messages — the
    /// same trigger, keyframes and pivot as the header's `BellMark`, because a
    /// bell that swings differently in two places reads as two bells.
    @State private var shake = 0

    private struct Item {
        let tab: AppTab
        let title: String
        let icon: String
        /// The unread bell carries its own brand-red badge, so it is drawn as
        /// artwork rather than a tinted glyph — the tab tint would flatten the
        /// badge back into the bell.
        var templated = true
        /// A second layer drawn over `icon`, swinging a beat behind it — the
        /// bell's clapper. Generated in the same box as the body, so stacking
        /// the two is the whole alignment.
        var clapper: String?
    }

    /// The bell's own badge carries the unread state, the same way it does in
    /// the iOS tab bar — not a second dot stacked beside it.
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
            // Icon only, matching iOS. Three destinations whose glyphs are a
            // bell, a key and a gear do not need naming, and the name is still
            // spoken and shown on hover.
            ZStack {
                Image(icon)
                    .renderingMode(templated ? .template : .original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .bellSwing(trigger: shake)
                if let clapper {
                    // The unread body draws itself in fg rather than taking the
                    // tab tint, so its clapper has to match it, not the tint.
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
