import SwiftUI

struct SettingsTabsView: View {
    var body: some View {
        TabView {
            NavigationStack {
                KeysView()
            }
            .tabItem { Label("Keys", systemImage: "key") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .frame(width: 520, height: 460)
    }
}
