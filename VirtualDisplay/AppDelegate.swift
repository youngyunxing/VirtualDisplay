import Cocoa

struct DisplayPreset {
    let id: String
    let name: String
    let logicalWidth: Int
    let logicalHeight: Int
    let refreshRate: Int
    let ppi: Int
    let vendorID: UInt32
    let productID: UInt32
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let selectedPresetIDKey = "selectedPresetID"
    private let hiDPIEnabledKey = "hiDPIEnabled"

    private let presets: [DisplayPreset] = [
        DisplayPreset(
            id: "oppo-pad-3",
            name: "OPPO Pad 3（2800×2000）",
            logicalWidth: 2800,
            logicalHeight: 2000,
            refreshRate: 60,
            ppi: 296,
            vendorID: 0x0001,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "macbook-m1-13-native",
            name: "MacBook M1 13 寸原生（2560×1600）",
            logicalWidth: 2560,
            logicalHeight: 1600,
            refreshRate: 60,
            ppi: 227,
            vendorID: 0x0002,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "macbook-m1-13-scaled",
            name: "MacBook M1 13 寸缩放（1440×900）",
            logicalWidth: 1440,
            logicalHeight: 900,
            refreshRate: 60,
            ppi: 227,
            vendorID: 0x0002,
            productID: 0x0002
        ),
        DisplayPreset(
            id: "4k-uhd",
            name: "4K UHD（3840×2160）",
            logicalWidth: 3840,
            logicalHeight: 2160,
            refreshRate: 60,
            ppi: 163,
            vendorID: 0x0003,
            productID: 0x0001
        ),
        DisplayPreset(
            id: "1080p-fhd",
            name: "1080p FHD（1920×1080）",
            logicalWidth: 1920,
            logicalHeight: 1080,
            refreshRate: 60,
            ppi: 92,
            vendorID: 0x0004,
            productID: 0x0001
        ),
    ]

    var statusItem: NSStatusItem!
    var display: CGVirtualDisplay?

    private var selectedPresetID: String {
        didSet {
            UserDefaults.standard.set(selectedPresetID, forKey: selectedPresetIDKey)
        }
    }

    private var hiDPIEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hiDPIEnabled, forKey: hiDPIEnabledKey)
        }
    }

    override init() {
        selectedPresetID = UserDefaults.standard.string(forKey: selectedPresetIDKey) ?? presets[0].id
        hiDPIEnabled = UserDefaults.standard.bool(forKey: hiDPIEnabledKey)
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "VirtualDisplay")
        }

        buildMenu()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let preset = self?.presets.first(where: { $0.id == self?.selectedPresetID }) {
                self?.applyPreset(preset)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return false
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? String,
              let preset = presets.first(where: { $0.id == presetID }) else { return }
        applyPreset(preset)
    }

    @objc private func toggleHiDPI(_ sender: NSMenuItem) {
        hiDPIEnabled.toggle()
        if let preset = presets.first(where: { $0.id == selectedPresetID }) {
            applyPreset(preset)
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        for preset in presets {
            let item = NSMenuItem(
                title: preset.name,
                action: #selector(presetSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.id
            if preset.id == selectedPresetID {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let hiDPIItem = NSMenuItem(
            title: "HiDPI 模式（2× 更清晰）",
            action: #selector(toggleHiDPI(_:)),
            keyEquivalent: ""
        )
        hiDPIItem.target = self
        hiDPIItem.state = hiDPIEnabled ? .on : .off
        menu.addItem(hiDPIItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func applyPreset(_ preset: DisplayPreset) {
        selectedPresetID = preset.id

        // Release the previous virtual display so we can recreate it with a
        // descriptor that matches the preset's physical size and pixel density.
        display = nil

        let hiDPI: UInt32 = hiDPIEnabled ? 1 : 0
        let physicalWidth = hiDPI == 1 ? preset.logicalWidth * 2 : preset.logicalWidth
        let physicalHeight = hiDPI == 1 ? preset.logicalHeight * 2 : preset.logicalHeight

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.global(qos: .userInitiated))
        descriptor.name = "VirtualDisplay"
        descriptor.maxPixelsWide = UInt32(physicalWidth)
        descriptor.maxPixelsHigh = UInt32(physicalHeight)
        descriptor.sizeInMillimeters = CGSize(
            width: Double(physicalWidth) / Double(preset.ppi) * 25.4,
            height: Double(physicalHeight) / Double(preset.ppi) * 25.4
        )
        // Use standard sRGB primaries so ColorSync can match a cached profile.
        descriptor.whitePoint = CGPoint(x: 0.3127, y: 0.3290)
        descriptor.redPrimary = CGPoint(x: 0.6400, y: 0.3300)
        descriptor.greenPrimary = CGPoint(x: 0.3000, y: 0.6000)
        descriptor.bluePrimary = CGPoint(x: 0.1500, y: 0.0600)
        descriptor.productID = preset.productID
        descriptor.vendorID = preset.vendorID
        let serialMillis = Date().timeIntervalSince1970 * 1000
        descriptor.serialNumber = UInt32(serialMillis.truncatingRemainder(dividingBy: Double(UInt32.max)))

        let display = CGVirtualDisplay(descriptor: descriptor)
        self.display = display

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = hiDPI
        settings.rotation = 0
        settings.modes = [
            CGVirtualDisplayMode(
                width: UInt(preset.logicalWidth),
                height: UInt(preset.logicalHeight),
                refreshRate: CGFloat(preset.refreshRate)
            ),
        ]

        _ = display.apply(settings)

        // On some systems macOS will default the new virtual display to a HiDPI
        // mode even when hiDPI is disabled, or it will mirror the built-in Retina
        // display. Try to select the exact 1x mode we requested.
        if hiDPI == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.selectRequestedMode(for: preset, displayID: display.displayID)
            }
        }

        buildMenu()
    }

    private func selectRequestedMode(for preset: DisplayPreset, displayID: CGDirectDisplayID) {
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] else { return }
        guard let targetMode = modes.first(where: {
            Int($0.width) == preset.logicalWidth
                && Int($0.height) == preset.logicalHeight
                && Int($0.pixelWidth) == preset.logicalWidth
                && Int($0.pixelHeight) == preset.logicalHeight
        }) else { return }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == CGError.success else { return }
        guard CGConfigureDisplayWithDisplayMode(config, displayID, targetMode, nil) == CGError.success else {
            CGCancelDisplayConfiguration(config)
            return
        }
        CGCompleteDisplayConfiguration(config, .forSession)
    }
}
