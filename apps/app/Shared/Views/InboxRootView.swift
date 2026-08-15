import SwiftData
import SwiftUI

struct InboxRootView: View {
    @Environment(AppModel.self) private var model
    #if DEBUG
    @Environment(\.modelContext) private var context
    #endif
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        @Bindable var model = model
        #if os(iOS)
        Group {
            if #available(iOS 18.0, *) {
                modernTabs
            } else {
                legacyTabs
            }
        }
        .task { await shotSetup() }
        .onChange(of: model.selectedTab) { Haptics.selection() }
        .onChange(of: model.selectedTab, initial: true) { normalizeSelection() }
        .onChange(of: sizeClass) { normalizeSelection() }
        #else
        VStack(spacing: 0) {
            Group {
                switch model.selectedTab {
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

    /// The App Store screenshot script's hook. Seeding through the ••• menu
    /// needs a tap the script would have to aim by pixel; these run the same
    /// seed from launch environment instead, so a capture is
    /// launch → settle → screenshot with nothing to miss. `#if DEBUG` for the
    /// same reason as `NOTIFI_START_TAB`: it exists for the script, nothing
    /// else may set it.
    private func shotSetup() async {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        guard env["NOTIFI_SEED_SAMPLE"] == "1" else { return }
        SampleData.seed(into: context, keyIDs: model.sync?.keys.map(\.id) ?? [])
        if env["NOTIFI_OPEN_SAMPLE_MESSAGE"] == "1" {
            // The push happens after the feed has the seeded rows, or the
            // detail resolves an id nothing holds yet and shows "not found".
            try? await Task.sleep(for: .milliseconds(400))
            model.path.append(SampleData.idFloor)
        }
        #endif
    }

    #if os(iOS)
    private func normalizeSelection() {
        guard sizeClass == .regular, model.selectedTab == .search else { return }
        model.selectedTab = .inbox
    }

    @available(iOS 18.0, *)
    private var modernTabs: some View {
        @Bindable var model = model
        return TabView(selection: $model.selectedTab) {
            Tab(value: AppTab.inbox) {
                NavigationStack(path: $model.path) {
                    InboxView()
                        .navigationDestination(for: Int.self) { serverID in
                            MessageDetailView(serverID: serverID)
                        }
                }
            } label: {
                Label(Copy.Tabs.notifications,
                      image: model.hasUnread ? "BellTabUnread" : "BellTab")
                    .labelStyle(.iconOnly)
            }

            Tab(value: AppTab.keys) {
                NavigationStack { KeysView() }
            } label: {
                Label(Copy.Tabs.keys, image: "akar-key").labelStyle(.iconOnly)
            }

            Tab(value: AppTab.settings) {
                NavigationStack { SettingsView() }
            } label: {
                Label(Copy.Tabs.settings, image: "akar-gear").labelStyle(.iconOnly)
            }

            if sizeClass == .compact,
               model.selectedTab == .inbox || model.selectedTab == .search {
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
                .tabItem {
                    Label(Copy.Tabs.notifications,
                          image: model.hasUnread ? "BellTabUnread" : "BellTab")
                        .labelStyle(.iconOnly)
                }
                .tag(AppTab.inbox)

                NavigationStack {
                    KeysView()
                }
                .tabItem { Label(Copy.Tabs.keys, image: "akar-key").labelStyle(.iconOnly) }
                .tag(AppTab.keys)

                NavigationStack {
                    SettingsView()
                }
                .tabItem { Label(Copy.Tabs.settings, image: "akar-gear").labelStyle(.iconOnly) }
                .tag(AppTab.settings)
            }
        .tint(Theme.fg)
    }
    #endif
}
