#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

@MainActor
final class ReaderWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var model: AppModel?
    private var container: ModelContainer?

    private static let frameName = "reader"
    private static let fullScreenKey = "readerFullScreen"

    func configure(model: AppModel, container: ModelContainer) {
        self.model = model
        self.container = container
        NotificationCenter.default.addObserver(
            self, selector: #selector(someWindowWillClose),
            name: NSWindow.willCloseNotification, object: nil
        )
    }

    var isVisible: Bool { window?.isVisible ?? false }

    var isKey: Bool { window?.isKeyWindow ?? false }

    var isOnScreen: Bool {
        guard let window, window.isVisible, !window.isMiniaturized else { return false }
        return true
    }

    var isInFront: Bool {
        guard let window, isOnScreen, NSApp.isActive, window.isMainWindow else { return false }
        return window.occlusionState.contains(.visible)
    }

    func close() { window?.performClose(nil) }

    func show() {
        guard let window = window ?? makeWindow() else { return }
        NSApp.setActivationPolicy(.regular)
        claimSettingsMenuItem()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let wantsFullScreen = UserDefaults.standard.bool(forKey: Self.fullScreenKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            if wantsFullScreen, !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }

    private func makeWindow() -> NSWindow? {
        guard let model, let container else { return nil }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = Copy.Push.fallbackTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 880, height: 560)
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        window.delegate = self

        let root = ReaderView()
            .environment(model)
            .modelContainer(container)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 1100, height: 700))

        if !window.setFrameUsingName(Self.frameName) { window.center() }
        window.setFrameAutosaveName(Self.frameName)
        self.window = window
        return window
    }

    private func claimSettingsMenuItem() {
        guard let item = NSApp.mainMenu?.items.first?.submenu?.items.first(where: {
            $0.keyEquivalent == "," && $0.keyEquivalentModifierMask == .command
        }) else { return }
        item.target = self
        item.action = #selector(showSettingsPane)
    }

    @objc private func showSettingsPane() {
        model?.readerPane = .settings
        show()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window else { return }
        UserDefaults.standard.set(window.styleMask.contains(.fullScreen), forKey: Self.fullScreenKey)
    }

    @objc private func someWindowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.settleActivationPolicy() }
    }

    private func settleActivationPolicy() {
        NSApp.setActivationPolicy(isVisible ? .regular : .accessory)
    }
}

struct ReaderView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]
    @AppStorage("readerSidebarWidth") private var sidebarWidth = 360.0

    static let sidebarRange: ClosedRange<Double> = 360...440

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            InboxView()
                .frame(width: min(max(sidebarWidth, Self.sidebarRange.lowerBound),
                                  Self.sidebarRange.upperBound))
            ReaderDivider(width: $sidebarWidth)
            ReaderPaneView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.contentMeasure, Theme.readerMeasure)
                .environment(\.grainEnabled, false)
        }
        .environment(\.isReaderWindow, true)
        .geistSurface(model)
        .onAppear {
            #if DEBUG
            if SampleData.isEnabled, let index = SampleData.launchMessageIndex {
                model.readerSelection = SampleData.serverID(at: index)
            }
            if AppTab.launchOverride == .keys { model.readerPane = .keys }
            #endif
            if model.readerSelection == nil { model.readerSelection = messages.first?.serverID }
        }
        .onChange(of: messages.count) {
            let present = Set(messages.map(\.serverID))
            model.readerSelected = model.readerSelected.intersection(present)
            if let selected = model.readerSelection, !present.contains(selected) {
                if let first = messages.first?.serverID { model.readerSelect(first) } else {
                    model.readerSelection = nil
                }
            }
        }
        .alert(Copy.Reader.deleteSelectedTitle(Copy.Inbox.count(model.readerSelected.count)),
               isPresented: $model.readerConfirmingDelete) {
            Button(Copy.Common.delete, role: .destructive) { model.delete(serverIDs: model.readerSelected) }
            Button(Copy.Common.cancel, role: .cancel) {}
        } message: {
            Text(Copy.Inbox.deleteMessage)
        }
    }
}

private struct ReaderDivider: View {
    @Binding var width: Double
    @State private var startWidth: Double?

    var body: some View {
        Rectangle()
            .fill(Theme.chromeRuleColor)
            .frame(width: Theme.chromeRule)
            .ignoresSafeArea()
            .contentShape(Rectangle().inset(by: -4))
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let base = startWidth ?? width
                        startWidth = base
                        width = min(max(base + value.translation.width, ReaderView.sidebarRange.lowerBound),
                                    ReaderView.sidebarRange.upperBound)
                    }
                    .onEnded { _ in startWidth = nil }
            )
    }
}

private struct ReaderPaneView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.readerPane {
            case .inbox:
                if let serverID = model.readerSelection {
                    MessageDetailView(serverID: serverID).id(serverID)
                } else {
                    ReaderEmptyView()
                }
            case .keys:
                NavigationStack(path: $model.readerKeysPath) { KeysView() }
            case .settings:
                NavigationStack { SettingsView() }
            }
        }
        .overlay {
            if model.readerPresentingCreateKey {
                CreateKeyView { model.readerPresentingCreateKey = false }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(Theme.state, value: model.readerPresentingCreateKey)
    }
}

private struct ReaderEmptyView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image("EmptyBell")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(Theme.dim)
                    .grainGlyph()
                    .accessibilityHidden(true)
                Text(Copy.Reader.selectPrompt)
                    .font(Theme.body)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, Theme.gutter)
        }
        .background(StaticField())
    }
}

struct ReaderSwitch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Theme.headerActionSpacing) {
            ReaderSwitchButton(icon: "akar-key", label: Copy.Tabs.keys,
                               isOn: model.readerPane == .keys) {
                model.readerPane = model.readerPane == .keys ? .inbox : .keys
            }
            .keyboardShortcut("2", modifiers: .command)

            ReaderSwitchButton(icon: "akar-gear", label: Copy.Tabs.settings,
                               isOn: model.readerPane == .settings) {
                model.readerPane = model.readerPane == .settings ? .inbox : .settings
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

private struct ReaderSwitchButton: View {
    let icon: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 19
    @ScaledMetric(relativeTo: .body) private var frameSize: CGFloat = 34

    var body: some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(isOn ? Theme.brand : Theme.fg)
                .frame(width: frameSize, height: frameSize)
                .glassBackground(enabled: true)
                .geistHitArea(expandedBy: 5)
        }
        .buttonStyle(.geist)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
#endif
