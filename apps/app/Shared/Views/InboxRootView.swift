import SwiftData
import SwiftUI

struct InboxRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        #if os(iOS)
        TabView {
            NavigationStack(path: $model.path) {
                InboxView()
                    .navigationDestination(for: Int.self) { serverID in
                        MessageDetailView(serverID: serverID)
                    }
            }
            .tabItem { Label("Inbox", systemImage: "tray") }

            NavigationStack {
                KeysView()
            }
            .tabItem { Label("Keys", systemImage: "key") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        #else
        NavigationStack(path: $model.path) {
            InboxView()
                .navigationDestination(for: Int.self) { serverID in
                    MessageDetailView(serverID: serverID)
                }
        }
        #endif
    }
}
