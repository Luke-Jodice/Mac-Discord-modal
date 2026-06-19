import AppKit
import WebKit

/// Borderless windows can't normally become key, which would break text input.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) } // Esc closes
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: KeyablePanel!
    private let webController = WebViewController()

    private enum Keys {
        static let width = "panelWidth.v1"
        static let height = "panelHeight.v1"
    }
    private let minSize = NSSize(width: 480, height: 360)
    private let defaultSize = NSSize(width: 760, height: 520)

    private var anchorTopY: CGFloat = 0
    private var anchorMidX: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.fill",
                                   accessibilityDescription: "Discord")
            button.action = #selector(togglePanel(_:))
            button.target = self
        }

        let panel = KeyablePanel(contentViewController: webController)
        panel.styleMask = [.borderless, .fullSizeContentView, .resizable]
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self
        panel.minSize = minSize
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setContentSize(savedSize())

        // Round the corners of the embedded web content.
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 12
            contentView.layer?.masksToBounds = true
        }
        self.panel = panel

        installMenus()
    }

    private func savedSize() -> NSSize {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: Keys.width)
        let height = defaults.double(forKey: Keys.height)
        guard width >= minSize.width, height >= minSize.height else { return defaultSize }
        return NSSize(width: width, height: height)
    }

    /// A menu-bar-only app has no main menu, so standard key equivalents never
    /// reach the focused field. These hidden menus restore Edit (⌘X/C/V/A) and
    /// add zoom (⌘-/⌘=/⌘0); nil targets dispatch down the responder chain.
    private func installMenus() {
        let mainMenu = NSMenu()

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(WebViewController.zoomIn(_:)), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(WebViewController.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(WebViewController.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(WebViewController.actualSize(_:)), keyEquivalent: "0")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Toggle Channels", action: #selector(WebViewController.toggleChannels(_:)), keyEquivalent: "b")

        NSApp.mainMenu = mainMenu
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }

        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        anchorMidX = buttonRect.midX
        // visibleFrame.maxY is the bottom of the menu bar — pin the panel just under it.
        anchorTopY = screen.visibleFrame.maxY - 2

        positionPanel(recenter: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Top edge pinned just under the menu bar, clamped to the visible screen.
    /// `recenter` horizontally centers under the icon (on open); resizing keeps
    /// the current horizontal position so the panel doesn't jump around.
    private func positionPanel(recenter: Bool) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let size = panel.frame.size
        var x = recenter ? (anchorMidX - size.width / 2) : panel.frame.origin.x
        let minX = screen.visibleFrame.minX + 8
        let maxX = screen.visibleFrame.maxX - size.width - 8
        x = min(max(x, minX), maxX)
        let y = anchorTopY - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidResize(_ notification: Notification) {
        // setContentSize during launch fires this before `panel` is assigned.
        guard let panel, panel.isVisible else { return }
        positionPanel(recenter: false) // keep top pinned as the user resizes
        let size = panel.frame.size
        UserDefaults.standard.set(Double(size.width), forKey: Keys.width)
        UserDefaults.standard.set(Double(size.height), forKey: Keys.height)
    }
}
