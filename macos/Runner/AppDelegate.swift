import Cocoa
import FlutterMacOS
import UserNotifications
import Sparkle

let menuImageSize = NSSize(width: 23, height: 23)

extension NSImage.Name {
    static let grey = NSImage.Name("menu_icon")
    static let red = NSImage.Name("red_menu_icon")
    static let error = NSImage.Name("menu_error_icon")
}

@main
class AppDelegate: FlutterAppDelegate {
    var statusBarItem: NSStatusItem!
    let popover = NSPopover()
    @IBOutlet weak var window: MainFlutterWindow!

    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusBarItem.button {
            let image = NSImage(named: .red)
            image?.size = menuImageSize
            button.image = image
            button.action = #selector(togglePopover(_:))
        }

        // sparkle update stuff
        let sUUpdater = SUUpdater.shared()

        let flutterViewController = FlutterViewController.init()

        let notificationChannel = FlutterMethodChannel(name: "max.me.uk/notifications",
                binaryMessenger: flutterViewController.engine.binaryMessenger)

        var menuBarAnimater: Animater!

        notificationChannel.setMethodCallHandler { [self]
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            let menu_image: NSImage?
            switch call.method {
            case "red_menu_icon":
                menu_image = NSImage(named: .red)
                menu_image?.isTemplate = false
            case "grey_menu_icon":
                menu_image = NSImage(named: .grey)
                menu_image?.isTemplate = true
            case "error_menu_icon":
                menu_image = NSImage(named: .error)
                menu_image?.isTemplate = true
            case "animate":
                if let button = self.statusBarItem.button {
                    if menuBarAnimater != nil {
                        menuBarAnimater.invalidate()
                    }
                    menuBarAnimater = Animater(button: button)
                    menuBarAnimater.run()
                }
                menu_image = nil
            case "update":
                sUUpdater?.checkForUpdates(self)
                return
            case "set-sparkle-url":
                if let args = call.arguments as? Dictionary<String, Any>, let url = args["url"] as? String {
                    sUUpdater?.feedURL = URL(string: url)
                    return result(true)
                }
                return result(false)
            case "close_window":
                closePopover(sender: nil)
                return result(true)
            case "open_window":
                showPopover(sender: nil)
                return result(true)
            case "UUID":
                return result(hardwareUUID())
            case "set-pin-window":
                if let args = call.arguments as? Dictionary<String, Any>, let transient = args["transient"] as? Bool {
                    if (transient) {
                        // Close the popover when the user interacts with a user
                        // interface element outside the popover
                        popover.behavior = .transient
                    } else {
                        popover.behavior = .semitransient
                    }
                    return result(true)
                }
                return result(false)
            default:
                return
            }
            if (menu_image != nil) {
                if let button = statusBarItem.button {
                    menu_image?.size = menuImageSize
                    button.image = menu_image
                    result(0) // success
                }
            }
        }

        RegisterGeneratedPlugins(registry: flutterViewController)

        popover.contentViewController = flutterViewController

        // to connect to ws in background
        // very hacky: opens the popup out of the screen
        if let button = statusBarItem.button {
            popover.show(
                    relativeTo: NSRect(x: -1000, y: -1000, width: 0, height: 0),
                    of: button,
                    preferredEdge: NSRectEdge.minY
            )
        }
        closePopover(sender: nil)
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            if #available(OSX 10.14, *) {
                let center = UNUserNotificationCenter.current()
                center.removeAllDeliveredNotifications()
            }
            showPopover(sender: sender)
        }
    }

    func showPopover(sender: Any?) {
        if let screen = NSScreen.main {
            let rect = screen.frame
            let height = rect.size.height * 0.7  // 70% of window
            popover.contentSize = NSSize(width: height * 0.563, height: height)
            if let button = statusBarItem.button {
                popover.show(
                        relativeTo: button.bounds,
                        of: button,
                        preferredEdge: NSRectEdge.minY
                )
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePopover(sender: Any?) {
        popover.performClose(sender)
    }

    func hardwareUUID() -> String? {
        let matchingDict = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, matchingDict)
        defer {
            IOObjectRelease(platformExpert)
        }

        guard platformExpert != 0 else {
            return nil
        }
        return IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
                .takeRetainedValue() as? String
    }
}
