#if os(macOS)
import SwiftUI

/// Keys and Settings, pushed inside the menu bar popover instead of a separate window.
struct SettingsTabsView: View {
    @Environment(AppModel.self) private var model

    @State private var tab: Tab = .keys

    enum Tab: String, CaseIterable, Identifiable {
        case keys
        case settings

        var id: String { rawValue }
        var title: String { self == .keys ? "Keys" : "Settings" }
    }

    var body: some View {
        Group {
            switch tab {
            case .keys:
                KeysView()
            case .settings:
                SettingsView()
            }
        }
        .safeAreaInset(edge: .top) {
            MacNavBar(backTitle: "Inbox") {
                HStack(spacing: 10) {
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()

                    if tab == .keys {
                        Button {
                            model.presentingCreateKey = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Create key")
                    }
                }
            }
        }
    }
}
#endif
