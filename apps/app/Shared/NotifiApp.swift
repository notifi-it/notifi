import SwiftData
import SwiftUI

#if os(macOS)
import AppKit

@MainActor let macAppModel = AppModel()
@MainActor let macContainer = NotifiApp.makeContainer()
@MainActor let macMenuBar = MenuBarController()
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

    #if os(macOS)
    init() {
        MainActor.assumeIsolated {
            macMenuBar.configure(model: macAppModel, container: macContainer)
        }
    }
    #endif

    static func makeContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(for: Message.self)
            if let url = container.configurations.first?.url {
                OnDiskProtection.protect(url)
            }
            return container
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
        Settings {}
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.bootState {
            case .loading:
                ProgressView()
                    .tint(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .unsupported:
                UnsupportedDeviceView()
            case .unavailable:
                IdentityUnavailableView()
            case .needsRestoreAck:
                RestoreExplainerView()
            case .ready:
                InboxRootView()
            }
        }
        .tint(Theme.brand)
        .font(.inco(.body))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StaticField())
        .preferredColorScheme(model.appearance.colorScheme)
        #if os(macOS)
        .overlay {
            if model.presentingCreateKey {
                CreateKeyView { model.presentingCreateKey = false }
                    .environment(model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.presentingCreateKey)
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
                #if os(iOS)
                model.startLiveUpdates()
                #endif
            } else {
                #if os(iOS)
                model.stopLiveUpdates()
                #endif
            }
        }
    }
}
