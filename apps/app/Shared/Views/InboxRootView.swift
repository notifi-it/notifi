import SwiftData
import SwiftUI

struct InboxRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        #if os(iOS)
        // Two spellings of the same three destinations. The `Tab` builder is
        // iOS 18+, and the search role only becomes the tab-bar-morphs-into-a-
        // field interaction on 26 — but the app deploys to 17, where neither
        // exists. Below 18 the original `.tabItem` bar is kept as-is and there
        // is no search tab; the Inbox is still fully usable without one.
        if #available(iOS 18.0, *) {
            modernTabs
        } else {
            legacyTabs
        }
        #else
        // The same three destinations as iOS, in the same order, so the two
        // platforms are one product. SwiftUI's TabView is not used: on macOS it
        // renders as a top segmented control, and inside a popover there is no
        // tab bar at all. GeistTabBar draws it instead.
        VStack(spacing: 0) {
            Group {
                switch model.selectedTab {
                // `.search` has no tab of its own here — the Mac searches from
                // the Inbox header — but a notification or a restored session
                // can still hand this view the case, so it lands on the feed
                // that search would have been filtering.
                case .inbox, .search:
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

    #if os(iOS)
    @available(iOS 18.0, *)
    private var modernTabs: some View {
        @Bindable var model = model
        return TabView(selection: $model.selectedTab) {
            // The app's own bell rather than a generic inbox tray — this tab is
            // notifi itself, so it gets the logo. A tab item draws its asset at
            // the asset's own framing, and BellLogo is framed tight to the ink,
            // which would sit heavier here than the akar icons beside it — hence
            // BellTab, the same drawing in a looser box.
            // The mark's own badge carries the unread state, rather than a
            // second dot stacked next to it: the bell already has one, and two
            // would be the same fact twice.
            // Icon only. A bell, a key and a gear name themselves, and the
            // titles were the only text competing with the content scrolling
            // behind the bar. The label is kept for VoiceOver, which is why
            // these use the label closure rather than the title-and-image
            // initialiser — that one has no way to hide the words.
            Tab(value: AppTab.inbox) {
                NavigationStack(path: $model.path) {
                    InboxView()
                        .navigationDestination(for: Int.self) { serverID in
                            MessageDetailView(serverID: serverID)
                        }
                }
            } label: {
                Label("Notifications",
                      image: model.hasUnread ? "BellTabUnread" : "BellTab")
                    .labelStyle(.iconOnly)
            }

            Tab(value: AppTab.keys) {
                NavigationStack { KeysView() }
            } label: {
                Label("Keys", image: "akar-key").labelStyle(.iconOnly)
            }

            Tab(value: AppTab.settings) {
                NavigationStack { SettingsView() }
            } label: {
                Label("Settings", image: "akar-gear").labelStyle(.iconOnly)
            }

            // The role is what buys the morph: on iOS 26 the tab bar itself
            // becomes the search field when this is tapped. An ordinary tab
            // with a magnifying glass gets none of that.
            //
            // Present only alongside the feed, because that is the only thing
            // it searches. Offered on Keys or Settings it is a control that
            // either does nothing or silently changes tab to answer — and a
            // search box that moves you somewhere else to show its results is
            // worse than no search box on those screens. `.search` is kept in
            // the condition so the tab does not vanish out from under itself
            // while it is the selected one.
            if model.selectedTab == .inbox || model.selectedTab == .search {
                Tab(value: AppTab.search, role: .search) {
                    NavigationStack { SearchView() }
                }
            }
        }
        .tint(Theme.fg)
    }

    private var legacyTabs: some View {
        @Bindable var model = model
        return TabView(selection: $model.selectedTab) {
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
                // Icon only. A bell, a key and a gear name themselves, and the
                // titles were the only text competing with the content scrolling
                // behind the bar. The label is kept for VoiceOver.
                .tabItem {
                    Label("Notifications",
                          image: model.hasUnread ? "BellTabUnread" : "BellTab")
                        .labelStyle(.iconOnly)
                }
                .tag(AppTab.inbox)

                NavigationStack {
                    KeysView()
                }
                .tabItem { Label("Keys", image: "akar-key").labelStyle(.iconOnly) }
                .tag(AppTab.keys)

                NavigationStack {
                    SettingsView()
                }
                .tabItem { Label("Settings", image: "akar-gear").labelStyle(.iconOnly) }
                .tag(AppTab.settings)
            }
        .tint(Theme.fg)
    }
    #endif
}
