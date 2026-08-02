import SwiftData
import SwiftUI

#if os(macOS)
import AppKit

@MainActor let macAppModel = AppModel()
@MainActor let macContainer = NotifiApp.makeContainer()
#endif

@main
struct NotifiApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    private let container = NotifiApp.makeContainer()
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #endif

    static func makeContainer() -> ModelContainer {
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
        Settings {
            SettingsTabsView()
                .environment(macAppModel)
        }
        .modelContainer(macContainer)
        #endif
    }
}

#if os(macOS)
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#endif

struct RootContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
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
        .tint(Color(red: 0.737, green: 0.129, blue: 0.133))
        .font(.custom("Inconsolata", size: 17, relativeTo: .body))
        #if os(macOS)
        .sheet(isPresented: $model.presentingCreateKey) {
            NavigationStack { CreateKeyView() }
                .environment(model)
        }
        #endif
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
