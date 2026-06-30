import Cocoa

struct DisplayPreset {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let refreshRate: Int
    let vendorID: UInt32
    let productID: UInt32
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let singleResolutionModeKey = "singleResolutionMode"
    private let activePresetIDsKey = "activePresetIDs"
    private let legacySelectedPresetIDKey = "selectedPresetID"

    private let presets: [DisplayPreset] = [
        DisplayPreset(
            id: "oppo-pad-3",
            name: "OPPO Pad 3（2800×2000）",
            width: 2800,
            height: 2000,
            refreshRate: 60,
            vendorID: 0x0001,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "macbook-m1-13-native",
            name: "MacBook M1 13 寸原生（2560×1600）",
            width: 2560,
            height: 1600,
            refreshRate: 60,
            vendorID: 0x0002,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "macbook-m1-13-scaled",
            name: "MacBook M1 13 寸缩放（1440×900）",
            width: 2880,
            height: 1800,
            refreshRate: 60,
            vendorID: 0x0002,
            productID: 0x0002
        ),
        DisplayPreset(
            id: "4k-uhd",
            name: "4K UHD（3840×2160）",
            width: 3840,
            height: 2160,
            refreshRate: 60,
            vendorID: 0x0003,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "1080p-fhd",
            name: "1080p FHD（1920×1080）",
            width: 1920,
            height: 1080,
            refreshRate: 60,
            vendorID: 0x0004,
            productID: 0x0001
        ),
    ]

    var statusItem: NSStatusItem!
    private var activeDisplays: [String: CGVirtualDisplay] = [:]
    private var displaySerialCounter: UInt32 = 0

    private var singleResolutionMode: Bool {
        didSet {
            UserDefaults.standard.set(singleResolutionMode, forKey: singleResolutionModeKey)
        }
    }

    private var activePresetIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(activePresetIDs), forKey: activePresetIDsKey)
        }
    }

    override init() {
        singleResolutionMode = UserDefaults.standard.object(forKey: singleResolutionModeKey) as? Bool ?? true

        if let ids = UserDefaults.standard.array(forKey: activePresetIDsKey) as? [String], !ids.isEmpty {
            activePresetIDs = Set(ids)
        } else if let legacyID = UserDefaults.standard.string(forKey: legacySelectedPresetIDKey) {
            activePresetIDs = [legacyID]
            UserDefaults.standard.removeObject(forKey: legacySelectedPresetIDKey)
        } else {
            activePresetIDs = [presets[0].id]
        }

        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "VirtualDisplay")
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.restoreActiveDisplays()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return false
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func statusBarButtonClicked(_: Any?) {
        guard let event = NSApp.currentEvent else { return }
        let isRightClick = event.buttonNumber == 1 || event.modifierFlags.contains(.control)
        if isRightClick {
            statusItem.popUpMenu(buildSettingsMenu())
        } else {
            statusItem.popUpMenu(buildPresetMenu())
        }
    }

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? String,
              let preset = presets.first(where: { $0.id == presetID }) else { return }

        if singleResolutionMode {
            activateSinglePreset(preset)
        } else {
            togglePreset(preset)
        }
    }

    @objc private func toggleSingleResolutionMode(_: NSMenuItem) {
        singleResolutionMode.toggle()

        if singleResolutionMode && activePresetIDs.count > 1 {
            // Keep the first active preset in menu order.
            if let firstActiveID = presets.first(where: { activePresetIDs.contains($0.id) })?.id,
               let preset = presets.first(where: { $0.id == firstActiveID }) {
                activeDisplays.removeAll()
                activePresetIDs = [firstActiveID]
                createDisplay(for: preset)
            }
        }
    }

    private func buildPresetMenu() -> NSMenu {
        let menu = NSMenu()

        for preset in presets {
            let item = NSMenuItem(
                title: preset.name,
                action: #selector(presetSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.id
            if activePresetIDs.contains(preset.id) {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        return menu
    }

    private func buildSettingsMenu() -> NSMenu {
        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "设置", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        let singleModeItem = NSMenuItem(
            title: "单分辨率模式",
            action: #selector(toggleSingleResolutionMode(_:)),
            keyEquivalent: ""
        )
        singleModeItem.target = self
        singleModeItem.state = singleResolutionMode ? .on : .off
        menu.addItem(singleModeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        return menu
    }

    private func restoreActiveDisplays() {
        let validIDs = activePresetIDs.filter { id in presets.contains(where: { $0.id == id }) }
        if validIDs != activePresetIDs {
            activePresetIDs = validIDs.isEmpty ? [presets[0].id] : validIDs
        }

        if singleResolutionMode && activePresetIDs.count > 1 {
            if let firstActiveID = presets.first(where: { activePresetIDs.contains($0.id) })?.id {
                activePresetIDs = [firstActiveID]
            }
        }

        for id in activePresetIDs {
            if let preset = presets.first(where: { $0.id == id }) {
                createDisplay(for: preset)
            }
        }
    }

    private func activateSinglePreset(_ preset: DisplayPreset) {
        activeDisplays.removeAll()
        activePresetIDs = [preset.id]
        createDisplay(for: preset)
    }

    private func togglePreset(_ preset: DisplayPreset) {
        if activePresetIDs.contains(preset.id) {
            activePresetIDs.remove(preset.id)
            removeDisplay(for: preset.id)
        } else {
            activePresetIDs.insert(preset.id)
            createDisplay(for: preset)
        }
    }

    private func createDisplay(for preset: DisplayPreset) {
        // Menu resolution is the physical framebuffer sent to the remote client.
        // In HiDPI mode macOS renders at half the logical size and scales up.
        let physicalWidth = preset.width
        let physicalHeight = preset.height
        let logicalWidth = preset.width / 2
        let logicalHeight = preset.height / 2

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = "VirtualDisplay"
        descriptor.maxPixelsWide = UInt32(physicalWidth)
        descriptor.maxPixelsHigh = UInt32(physicalHeight)
        descriptor.productID = preset.productID
        descriptor.vendorID = preset.vendorID
        displaySerialCounter += 1
        descriptor.serialNumber = displaySerialCounter

        let display = CGVirtualDisplay(descriptor: descriptor)
        activeDisplays[preset.id] = display

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.rotation = 0
        settings.modes = [
            CGVirtualDisplayMode(
                width: UInt(logicalWidth),
                height: UInt(logicalHeight),
                refreshRate: CGFloat(preset.refreshRate)
            ),
        ]

        _ = display.apply(settings)
    }

    private func removeDisplay(for presetID: String) {
        activeDisplays.removeValue(forKey: presetID)
    }
}
