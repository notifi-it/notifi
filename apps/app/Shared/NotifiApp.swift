import SwiftData
import SwiftUI

@main
struct NotifiApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #endif

    @State private var model = AppModel()
    private let container = NotifiApp.makeContainer()

    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Message.self)
        } catch {
            fatalError("Failed to create the message store: \(error)")
        }
    }

    var body: some Scene {
        #if os(iOS)
        WindowGroup {
            RootContentView()
                .environment(model)
        }
        .modelContainer(container)
        #else
        MenuBarExtra("notifi", systemImage: "bell.badge") {
            RootContentView()
                .environment(model)
                .frame(width: 380, height: 520)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window("Inbox", id: "inbox") {
            RootContentView()
                .environment(model)
        }
        .modelContainer(container)

        Window("Create Key", id: "create-key") {
            CreateKeyView()
                .environment(model)
                .frame(minWidth: 420, minHeight: 360)
        }
        .modelContainer(container)
        .windowResizability(.contentSize)

        Settings {
            SettingsTabsView()
                .environment(model)
        }
        .modelContainer(container)
        #endif
    }
}

struct RootContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.bootState {
            case .loading:
                ProgressView()
            case .unsupported:
                UnsupportedDeviceView()
            case .needsRestoreAck:
                RestoreExplainerView()
            case .ready:
                InboxRootView()
            }
        }
        .task {
            model.bootstrap(context: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await model.refreshPermission()
                    await model.refresh()
                }
            }
        }
    }
}
