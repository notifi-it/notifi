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
            .tabItem { Label("Notifications", image: "akar-inbox") }
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
        NavigationStack(path: $model.path) {
            InboxView()
                .navigationDestination(for: Int.self) { serverID in
                    MessageDetailView(serverID: serverID)
                }
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsTabsView()
                    }
                }
        }
        #endif
    }
}
