import SwiftData
import SwiftUI

struct InboxRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        #if os(iOS)
        TabView(selection: $model.selectedTab) {
            NavigationStack(path: $model.path) {
                InboxView()
                    .navigationDestination(for: Int.self) { serverID in
                        MessageDetailView(serverID: serverID)
                    }
            }
            // The app's own bell rather than a generic inbox tray — this tab is
            // notifi itself, so it gets the logo. A tab item draws its asset at
            // the asset's own framing, and BellLogo is framed tight to the ink,
            // which would sit heavier here than the akar icons beside it — hence
            // BellTab, the same drawing in a looser box.
            // The mark's own badge carries the unread state, rather than a
            // second dot stacked next to it: the bell already has one, and two
            // would be the same fact twice.
            .tabItem {
                Label("Notifications",
                      image: model.hasUnread ? "BellTabUnread" : "BellTab")
            }
            .tag(AppTab.inbox)

            NavigationStack {
                KeysView()
            }
            .tabItem { Label("Keys", image: "akar-key") }
            .tag(AppTab.keys)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", image: "akar-gear") }
            .tag(AppTab.settings)
        }
        .tint(Theme.fg)
        #else
        // The same three destinations as iOS, in the same order, so the two
        // platforms are one product. SwiftUI's TabView is not used: on macOS it
        // renders as a top segmented control, and inside a popover there is no
        // tab bar at all. GeistTabBar draws it instead.
        VStack(spacing: 0) {
            Group {
                switch model.selectedTab {
                case .inbox:
                    NavigationStack(path: $model.path) {
                        InboxView()
                            .navigationDestination(for: Int.self) { serverID in
                                MessageDetailView(serverID: serverID)
                            }
                    }
                case .keys:
                    NavigationStack { KeysView() }
                case .settings:
                    NavigationStack { SettingsView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            GeistTabBar(selection: $model.selectedTab)
        }
        #endif
    }
}
