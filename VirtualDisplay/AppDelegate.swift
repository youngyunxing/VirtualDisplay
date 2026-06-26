import Cocoa

struct DisplayPreset {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let refreshRate: Int
    let hiDPI: UInt32
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let selectedPresetIDKey = "selectedPresetID"

    private let presets: [DisplayPreset] = [
        DisplayPreset(
            id: "oppo-pad-3",
            name: "OPPO Pad 3（2800×2000 HiDPI）",
            width: 1400,
            height: 1000,
            refreshRate: 60,
            hiDPI: 1
        ),
        DisplayPreset(
            id: "macbook-m1-13-native",
            name: "MacBook M1 13 寸原生（2560×1600）",
            width: 2560,
            height: 1600,
            refreshRate: 60,
            hiDPI: 0
        ),
        DisplayPreset(
            id: "macbook-m1-13-scaled",
            name: "MacBook M1 13 寸缩放（2880×1800 HiDPI）",
            width: 1440,
            height: 900,
            refreshRate: 60,
            hiDPI: 1
        ),
        DisplayPreset(
            id: "4k-uhd",
            name: "4K UHD（3840×2160 HiDPI）",
            width: 1920,
            height: 1080,
            refreshRate: 60,
            hiDPI: 1
        ),
        DisplayPreset(
            id: "1080p-fhd",
            name: "1080p FHD（1920×1080）",
            width: 1920,
            height: 1080,
            refreshRate: 60,
            hiDPI: 0
        ),
    ]

    var statusItem: NSStatusItem!
    var display: CGVirtualDisplay?

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
            self?.createVirtualDisplay()
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

    private func createVirtualDisplay() {
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = "VirtualDisplay"
        descriptor.maxPixelsWide = 3840
        descriptor.maxPixelsHigh = 2160
        descriptor.sizeInMillimeters = CGSize(width: 1600, height: 1000)
        descriptor.productID = 0x1234
        descriptor.vendorID = 0x3456
        descriptor.serialNum = 0x0001

        let display = CGVirtualDisplay(descriptor: descriptor)
        self.display = display

        if let preset = presets.first(where: { $0.id == selectedPresetID }) {
            applyPreset(preset)
        }
    }

    private func applyPreset(_ preset: DisplayPreset) {
        selectedPresetID = preset.id

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = preset.hiDPI
        settings.modes = [
            CGVirtualDisplayMode(
                width: UInt(preset.width),
                height: UInt(preset.height),
                refreshRate: CGFloat(preset.refreshRate)
            ),
        ]

        display?.apply(settings)
        buildMenu()
    }
}
