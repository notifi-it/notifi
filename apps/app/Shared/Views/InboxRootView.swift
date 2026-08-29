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
                            .navigationDestination(for: CachedKey.self) { key in
                                KeyDetailView(keyID: key.id)
                            }
                    }
                case .keys:
                    NavigationStack(path: $model.keysPath) { KeysView() }
                case .settings:
                    NavigationStack { SettingsView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            GeistTabBar(selection: $model.selectedTab)
        }
        .task { await shotSetup() }
        #endif
    }

    private func shotSetup() async {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        guard env["NOTIFI_SEED_SAMPLE"] == "1" else { return }
        SampleData.seed(into: context, keyIDs: model.sync?.keys.map(\.id) ?? [])
        if SampleData.opensSampleMessage {
            try? await Task.sleep(for: .milliseconds(400))
            model.path.append(SampleData.serverID(at: 1))
        }
        if let index = SampleData.launchKeyIndex, index < SampleData.keys.count {
            try? await Task.sleep(for: .milliseconds(400))
            model.keysPath = [SampleData.keys[index]]
        }
        SampleData.screenDidAppear()
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
                        .navigationDestination(for: CachedKey.self) { key in
                            KeyDetailView(keyID: key.id)
                        }
                }
            } label: {
                Label(Copy.Tabs.inbox,
                      image: model.hasUnread ? "BellTabUnread" : "BellTab")
                    .labelStyle(.iconOnly)
            }

            Tab(value: AppTab.keys) {
                NavigationStack(path: $model.keysPath) { KeysView() }
            } label: {
                Label(Copy.Tabs.keys, image: "akar-key").labelStyle(.iconOnly)
            }

            Tab(value: AppTab.settings) {
                NavigationStack { SettingsView() }
            } label: {
                Label(Copy.Tabs.settings, image: "akar-gear").labelStyle(.iconOnly)
            }

            if sizeClass == .compact, model.path.isEmpty,
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
                        .navigationDestination(for: CachedKey.self) { key in
                            KeyDetailView(keyID: key.id)
                        }
                }
                .tabItem {
                    Label(Copy.Tabs.inbox,
                          image: model.hasUnread ? "BellTabUnread" : "BellTab")
                        .labelStyle(.iconOnly)
                }
                .tag(AppTab.inbox)

                NavigationStack(path: $model.keysPath) {
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
