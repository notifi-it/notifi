#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

extension Notification.Name {
    static let notifiNewMessages = Notification.Name("notifi.newMessages")
    static let notifiUnreadChanged = Notification.Name("notifi.unreadChanged")
    static let notifiOpenPanel = Notification.Name("notifi.openPanel")
}

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var animator: BellAnimator?
    private var model: AppModel?
    private var container: ModelContainer?

    private let panelSize = NSSize(width: 460, height: 700)

    func configure(model: AppModel, container: ModelContainer) {
        self.model = model
        self.container = container

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = panelSize

        let content = RootContentView()
            .environment(model)
            .modelContainer(container)
            .frame(width: panelSize.width, height: panelSize.height)

        let hosting = NSHostingController(rootView: AnyView(content))
        // Clear the hosting view's opaque backing so the popover's own vibrancy
        // (the glass) shows through instead of being flattened by a solid layer.
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear
        popover.contentViewController = hosting

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(togglePanel(_:))
        statusItem = item

        NotificationCenter.default.addObserver(
            self, selector: #selector(unreadChanged),
            name: .notifiUnreadChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(newMessagesArrived),
            name: .notifiNewMessages, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(openPanel),
            name: .notifiOpenPanel, object: nil
        )

        render(angle: 0)
    }

    private var hasUnread: Bool { model?.hasUnread ?? false }

    private func render(angle: CGFloat) {
        statusItem?.button?.image = MenuBarIconRenderer.bell(unread: hasUnread, angle: angle)
    }

    @objc private func unreadChanged() {
        if animator == nil { render(angle: 0) }
    }

    @objc private func newMessagesArrived() {
        animator?.stop()
        animator = BellAnimator { [weak self] angle in
            self?.render(angle: angle)
        } completion: { [weak self] in
            self?.animator = nil
            self?.render(angle: 0)
        }
        animator?.start()
    }

    @objc private func openPanel() {
        guard !popover.isShown, let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
    }

    @objc private func togglePanel(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
    }
}

enum MenuBarIconRenderer {
    static func bell(unread: Bool, angle: CGFloat) -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }

            if angle != 0 {
                let transform = NSAffineTransform()
                transform.translateX(by: rect.width / 2, yBy: rect.height / 2)
                transform.rotate(byDegrees: angle)
                transform.translateX(by: -rect.width / 2, yBy: -rect.height / 2)
                transform.concat()
            }

            if let bell = NSImage(named: "menu_icon") {
                bell.isTemplate = true
                bell.draw(in: rect)
                NSColor.labelColor.set()
                rect.fill(using: .sourceAtop)
            }

            if unread {
                let diameter = rect.width * 0.30
                let center = NSPoint(x: rect.width * 0.66, y: rect.height * 0.78)
                let dot = NSRect(
                    x: center.x - diameter / 2,
                    y: center.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

@MainActor
final class BellAnimator {
    private static let angles: [CGFloat] = {
        let raw = "-20,-15.1022,-10.5422,-6.32,-2.43556,1.11111,4.32,7.19111,9.72444,11.92,13.7778,15.2978,16.48,17.3244,17.8311,18,13.6178,9.53778,5.76,2.28444,-0.888889,-3.76,-6.32889,-8.59556,-10.56,-12.2222,-13.5822,-14.64,-15.3956,-15.8489,-16,-12.1333,-8.53333,-5.2,-2.13333,0.666667,3.2,5.46667,7.46667,9.2,10.6667,11.8667,12.8,13.4667,13.8667,14,10.52,7.28,4.28,1.52,-1,-3.28,-5.32,-7.12,-8.68,-10,-11.08,-11.92,-12.52,-12.88,-13,-9.77778,-6.77778,-4,-1.44444,0.888889,3,4.88889,6.55556,8,9.22222,10.2222,11,11.5556,11.8889,12,9.16444,6.52444,4.08,1.83111,-0.222222,-2.08,-3.74222,-5.20889,-6.48,-7.55556,-8.43556,-9.12,-9.60889,-9.90222,-10,-7.68,-5.52,-3.52,-1.68,0,1.52,2.88,4.08,5.12,6,6.72,7.28,7.68,7.92,8,6.19556,4.51556,2.96,1.52889,0.222222,-0.96,-2.01778,-2.95111,-3.76,-4.44444,-5.00444,-5.44,-5.75111,-5.93778,-6,-4.71111,-3.51111,-2.4,-1.37778,-0.444444,0.4,1.15556,1.82222,2.4,2.88889,3.28889,3.6,3.82222,3.95556,4,3.22667,2.50667,1.84,1.22667,0.666667,0.16,-0.293333,-0.693333,-1.04,-1.33333,-1.57333,-1.76,-1.89333,-1.97333,-2,-1.74222,-1.50222,-1.28,-1.07556,-0.888889,-0.72,-0.568889,-0.435556,-0.32,-0.222222,-0.142222,-0.08,-0.0355556,-0.0088888"
        return raw.split(separator: ",").compactMap { Double($0).map { CGFloat($0) } }
    }()

    private var index = 0
    private var timer: Timer?
    private let step: (CGFloat) -> Void
    private let completion: () -> Void

    init(step: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
        self.step = step
        self.completion = completion
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard index < Self.angles.count else {
            stop()
            completion()
            return
        }
        step(Self.angles[index])
        index += 1
    }
}
#endif
