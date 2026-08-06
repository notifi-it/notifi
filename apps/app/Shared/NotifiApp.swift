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
    // The status item is built here, not in the app delegate.
    //
    // With `Settings` as the only scene the delegate was never instantiated, so
    // nothing ever created a status item; the app then owned no UI at all and
    // macOS terminated it about twelve seconds after launch, before it could
    // register the device. `App.init()` runs at launch regardless of scenes, so
    // the item — and with it the NSPopover — is guaranteed to exist.
    init() {
        MainActor.assumeIsolated {
            macMenuBar.configure(model: macAppModel, container: macContainer)
        }
    }
    #endif

    static func makeContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(for: Message.self)
            // The store stays in backups on purpose: an archive that outlives its
            // keychain identity is exactly how a restored phone is detected. What it
            // does not need is to sit unprotected on disk between unlocks.
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
        // The popover is the whole UI, so there is no scene to show — but `App`
        // demands one, and an empty Settings scene never opens a window.
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
                    .background(Theme.bg)
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
        .font(.custom("Inconsolata", size: 17, relativeTo: .body))
        // Fill before painting the ground. States like the boot error size to
        // their own content, so without this the popover shows the black panel
        // as a band with the vibrancy material above and below it.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        // Geist is a dark-only system — there is no light palette by design.
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        #if os(macOS)
        // Covers the popover rather than being presented into it. See the note
        // on `CreateKeyView.onClose` for why this is not a sheet.
        .overlay {
            if model.presentingCreateKey {
                CreateKeyView { model.presentingCreateKey = false }
                    .environment(model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
                    // A full-window pane sliding up is the largest movement the
                    // app makes, and it was the one piece of motion still
                    // ungated. Under Reduce Motion it crossfades instead of
                    // travelling; it still arrives, it just does not fly.
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
            }
        }
    }
}
