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
            ppi: 128,
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
    private var displaySerialCounter: UInt32 = 0

    private var selectedPresetID: String {
        didSet {
            UserDefaults.standard.set(selectedPresetID, forKey: selectedPresetIDKey)
        }
    }

    override init() {
        selectedPresetID = UserDefaults.standard.string(forKey: selectedPresetIDKey) ?? presets[0].id
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
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func applyPreset(_ preset: DisplayPreset) {
        selectedPresetID = preset.id

        // Release the previous virtual display so we can recreate it with a
        // descriptor that matches the preset's physical size and pixel density.
        display = nil

        // Always render in HiDPI: the framebuffer is 2x the logical resolution.
        let physicalWidth = preset.logicalWidth * 2
        let physicalHeight = preset.logicalHeight * 2

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = "VirtualDisplay"
        descriptor.maxPixelsWide = UInt32(physicalWidth)
        descriptor.maxPixelsHigh = UInt32(physicalHeight)
        // sizeInMillimeters describes the logical display size, not the pixel count.
        descriptor.sizeInMillimeters = CGSize(
            width: Double(preset.logicalWidth) / Double(preset.ppi) * 25.4,
            height: Double(preset.logicalHeight) / Double(preset.ppi) * 25.4
        )
        // Use standard sRGB primaries so ColorSync can match a cached profile.
        descriptor.whitePoint = CGPoint(x: 0.3127, y: 0.3290)
        descriptor.redPrimary = CGPoint(x: 0.6400, y: 0.3300)
        descriptor.greenPrimary = CGPoint(x: 0.3000, y: 0.6000)
        descriptor.bluePrimary = CGPoint(x: 0.1500, y: 0.0600)
        descriptor.productID = preset.productID
        descriptor.vendorID = preset.vendorID
        displaySerialCounter += 1
        descriptor.serialNumber = displaySerialCounter

        let display = CGVirtualDisplay(descriptor: descriptor)
        self.display = display

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.rotation = 0
        settings.modes = [
            CGVirtualDisplayMode(
                width: UInt(preset.logicalWidth),
                height: UInt(preset.logicalHeight),
                refreshRate: CGFloat(preset.refreshRate)
            ),
        ]

        _ = display.apply(settings)

        buildMenu()
    }
}
