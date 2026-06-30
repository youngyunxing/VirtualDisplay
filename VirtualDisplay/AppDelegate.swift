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
            name: "OPPO Pad 3 2800×2000（1400×1000 HiDPI）",
            width: 2800,
            height: 2000,
            refreshRate: 60,
            vendorID: 0x0001,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "macbook-m1-13-native",
            name: "MacBook M1 13 寸原生 2560×1600（1280×800 HiDPI）",
            width: 2560,
            height: 1600,
            refreshRate: 60,
            vendorID: 0x0002,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "macbook-m1-13-scaled",
            name: "MacBook M1 13 寸缩放 2880×1800（1440×900 HiDPI）",
            width: 2880,
            height: 1800,
            refreshRate: 60,
            vendorID: 0x0002,
            productID: 0x0002
        ),
        DisplayPreset(
            id: "4k-uhd",
            name: "4K UHD 3840×2160（1920×1080 HiDPI）",
            width: 3840,
            height: 2160,
            refreshRate: 60,
            vendorID: 0x0003,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "1080p-fhd",
            name: "1080p FHD 1920×1080（960×540 HiDPI）",
            width: 1920,
            height: 1080,
            refreshRate: 60,
            vendorID: 0x0004,
            productID: 0x0001
        ),
    ]

    var statusItem: NSStatusItem!
    private var display: CGVirtualDisplay?
    private var lastOrderedPresetIDs: [String] = []

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
            self?.applyActivePresets()
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
            activePresetIDs = [preset.id]
            applyActivePresets(selecting: preset)
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
                activePresetIDs = [firstActiveID]
                applyActivePresets(selecting: preset)
            }
        } else {
            applyActivePresets()
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

    private func togglePreset(_ preset: DisplayPreset) {
        if activePresetIDs.contains(preset.id) {
            activePresetIDs.remove(preset.id)
        } else {
            activePresetIDs.insert(preset.id)
        }
        applyActivePresets(selecting: preset)
    }

    private func applyActivePresets(selecting selectedPreset: DisplayPreset? = nil) {
        let validIDs = activePresetIDs.filter { id in presets.contains(where: { $0.id == id }) }
        if validIDs != activePresetIDs {
            activePresetIDs = validIDs.isEmpty ? [presets[0].id] : validIDs
        }

        if singleResolutionMode && activePresetIDs.count > 1 {
            if let firstActiveID = presets.first(where: { activePresetIDs.contains($0.id) })?.id {
                activePresetIDs = [firstActiveID]
            }
        }

        let activePresets = presets.filter { activePresetIDs.contains($0.id) }
        guard !activePresets.isEmpty else { return }

        // Order presets so the one just selected (or the only one in single mode) is first.
        var orderedPresets = activePresets
        if let selected = selectedPreset,
           let index = orderedPresets.firstIndex(where: { $0.id == selected.id }) {
            orderedPresets.swapAt(0, index)
        }

        let orderedIDs = orderedPresets.map(\.id)
        guard orderedIDs != lastOrderedPresetIDs else { return }
        lastOrderedPresetIDs = orderedIDs

        // Create the virtual display once with a descriptor large enough for every
        // built-in preset. After that, just update settings.modes when the active
        // preset set changes; this avoids recreating the display and keeps the
        // macOS-assigned display number stable.
        if display == nil {
            let maxWidth = presets.map(\.width).max() ?? presets[0].width
            let maxHeight = presets.map(\.height).max() ?? presets[0].height

            let descriptor = CGVirtualDisplayDescriptor()
            descriptor.setDispatchQueue(DispatchQueue.main)
            descriptor.name = "VirtualDisplay"
            descriptor.maxPixelsWide = UInt32(maxWidth)
            descriptor.maxPixelsHigh = UInt32(maxHeight)
            descriptor.vendorID = 0x0001
            descriptor.productID = 0x0001
            descriptor.serialNumber = 1

            display = CGVirtualDisplay(descriptor: descriptor)
        }

        guard let display = display else { return }

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.rotation = 0
        settings.modes = orderedPresets.map { preset in
            CGVirtualDisplayMode(
                width: UInt(preset.width / 2),
                height: UInt(preset.height / 2),
                refreshRate: CGFloat(preset.refreshRate)
            )
        }

        _ = display.apply(settings)
    }
}
