import Cocoa

struct DisplayPreset: Codable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let refreshRate: Int
    let vendorID: UInt32
    let productID: UInt32
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let multiResolutionModeKey = "multiResolutionMode"
    private let activePresetIDsKey = "activePresetIDs"
    private let presetsKey = "presets"
    private let legacySelectedPresetIDKey = "selectedPresetID"
    private let legacyCustomPresetsKey = "customPresets"
    private let legacySingleResolutionModeKey = "singleResolutionMode"

    var statusItem: NSStatusItem!
    private var display: CGVirtualDisplay?
    private var displayMaxPixels: (width: Int, height: Int)?
    private var lastOrderedPresetIDs: [String] = []

    private var multiResolutionMode: Bool {
        didSet {
            UserDefaults.standard.set(multiResolutionMode, forKey: multiResolutionModeKey)
        }
    }

    private var activePresetIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(activePresetIDs), forKey: activePresetIDsKey)
        }
    }

    private var presets: [DisplayPreset] {
        didSet {
            savePresets()
        }
    }

    override init() {
        if UserDefaults.standard.object(forKey: multiResolutionModeKey) != nil {
            multiResolutionMode = UserDefaults.standard.bool(forKey: multiResolutionModeKey)
        } else if UserDefaults.standard.object(forKey: legacySingleResolutionModeKey) != nil {
            multiResolutionMode = !UserDefaults.standard.bool(forKey: legacySingleResolutionModeKey)
            UserDefaults.standard.removeObject(forKey: legacySingleResolutionModeKey)
        } else {
            multiResolutionMode = false
        }

        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([DisplayPreset].self, from: data),
           !decoded.isEmpty {
            presets = decoded
        } else if let legacyData = UserDefaults.standard.data(forKey: legacyCustomPresetsKey),
                  let legacy = try? JSONDecoder().decode([DisplayPreset].self, from: legacyData),
                  !legacy.isEmpty {
            presets = Self.defaultPresets() + legacy
            UserDefaults.standard.removeObject(forKey: legacyCustomPresetsKey)
        } else {
            presets = Self.defaultPresets()
        }

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
        statusItem.popUpMenu(buildPresetMenu())
    }

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? String,
              let preset = presets.first(where: { $0.id == presetID }) else { return }

        if !multiResolutionMode {
            activePresetIDs = [preset.id]
            applyActivePresets(selecting: preset)
        } else {
            togglePreset(preset)
        }
    }

    @objc private func addPreset(_: NSMenuItem) {
        showPresetEditor(preset: nil) { [weak self] newPreset in
            guard let self = self, let newPreset = newPreset else { return }
            self.presets.append(newPreset)
            if !self.multiResolutionMode {
                self.activePresetIDs = [newPreset.id]
                self.applyActivePresets(selecting: newPreset)
            } else {
                self.activePresetIDs.insert(newPreset.id)
                self.applyActivePresets(selecting: newPreset)
            }
        }
    }

    @objc private func editPreset(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? String,
              let index = presets.firstIndex(where: { $0.id == presetID }) else { return }

        let preset = presets[index]
        showPresetEditor(preset: preset) { [weak self] updatedPreset in
            guard let self = self, let updated = updatedPreset else { return }
            self.presets[index] = updated
            if self.activePresetIDs.contains(updated.id) {
                self.applyActivePresets(selecting: updated)
            } else {
                self.applyActivePresets()
            }
        }
    }

    @objc private func deletePreset(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? String,
              let index = presets.firstIndex(where: { $0.id == presetID }) else { return }

        let preset = presets[index]
        let alert = NSAlert()
        alert.messageText = "删除分辨率"
        alert.informativeText = "确定要删除「\(preset.name)」吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        presets.remove(at: index)
        activePresetIDs.remove(preset.id)

        if presets.isEmpty {
            presets = Self.defaultPresets()
            activePresetIDs = [presets[0].id]
        } else if activePresetIDs.isEmpty {
            activePresetIDs = [presets[0].id]
        }

        applyActivePresets()
    }

    @objc private func restoreDefaultPresets(_: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "恢复默认预设"
        alert.informativeText = "这将恢复所有内置分辨率预设，但保留你已添加的自定义预设。继续吗？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "恢复")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let defaultIDs = Set(Self.defaultPresets().map(\.id))
        let customPresets = presets.filter { !defaultIDs.contains($0.id) }
        presets = Self.defaultPresets() + customPresets
        applyActivePresets()
    }

    @objc private func toggleMultiResolutionMode(_: NSMenuItem) {
        multiResolutionMode.toggle()

        if !multiResolutionMode && activePresetIDs.count > 1 {
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
            menu.addItem(makePresetItem(preset: preset))
        }

        menu.addItem(NSMenuItem.separator())

        let addItem = NSMenuItem(
            title: "添加分辨率...",
            action: #selector(addPreset(_:)),
            keyEquivalent: ""
        )
        addItem.target = self
        menu.addItem(addItem)

        let restoreItem = NSMenuItem(
            title: "恢复默认预设",
            action: #selector(restoreDefaultPresets(_:)),
            keyEquivalent: ""
        )
        restoreItem.target = self
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

        let multiModeItem = NSMenuItem(
            title: "多分辨率模式",
            action: #selector(toggleMultiResolutionMode(_:)),
            keyEquivalent: ""
        )
        multiModeItem.target = self
        multiModeItem.state = multiResolutionMode ? .on : .off
        menu.addItem(multiModeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        return menu
    }

    private func makePresetItem(preset: DisplayPreset) -> NSMenuItem {
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

        let submenu = NSMenu()

        let editItem = NSMenuItem(
            title: "编辑...",
            action: #selector(editPreset(_:)),
            keyEquivalent: ""
        )
        editItem.target = self
        editItem.representedObject = preset.id
        submenu.addItem(editItem)

        let deleteItem = NSMenuItem(
            title: "删除",
            action: #selector(deletePreset(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.representedObject = preset.id
        submenu.addItem(deleteItem)

        item.submenu = submenu

        return item
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

        if !multiResolutionMode && activePresetIDs.count > 1 {
            if let firstActiveID = presets.first(where: { activePresetIDs.contains($0.id) })?.id {
                activePresetIDs = [firstActiveID]
            }
        }

        let activePresets = presets.filter { activePresetIDs.contains($0.id) }
        guard !activePresets.isEmpty else { return }

        var orderedPresets = activePresets
        if let selected = selectedPreset,
           let index = orderedPresets.firstIndex(where: { $0.id == selected.id }) {
            orderedPresets.swapAt(0, index)
        }

        let orderedIDs = orderedPresets.map(\.id)
        guard orderedIDs != lastOrderedPresetIDs else { return }
        lastOrderedPresetIDs = orderedIDs

        let requiredMaxWidth = presets.map(\.width).max() ?? presets[0].width
        let requiredMaxHeight = presets.map(\.height).max() ?? presets[0].height

        let needsRecreate = display == nil
            || (displayMaxPixels?.width ?? 0) < requiredMaxWidth
            || (displayMaxPixels?.height ?? 0) < requiredMaxHeight

        if needsRecreate {
            display = nil

            let descriptor = CGVirtualDisplayDescriptor()
            descriptor.setDispatchQueue(DispatchQueue.main)
            descriptor.name = "VirtualDisplay"
            descriptor.maxPixelsWide = UInt32(requiredMaxWidth)
            descriptor.maxPixelsHigh = UInt32(requiredMaxHeight)
            descriptor.vendorID = 0x0001
            descriptor.productID = 0x0001
            descriptor.serialNumber = 1

            display = CGVirtualDisplay(descriptor: descriptor)
            displayMaxPixels = (requiredMaxWidth, requiredMaxHeight)
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

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }

    private static func defaultPresets() -> [DisplayPreset] {
        return [
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
            DisplayPreset(
                id: "macbook-m1-13-native",
                name: "MacBook 经典 13 寸原生 2560×1600（1280×800 HiDPI）",
                width: 2560,
                height: 1600,
                refreshRate: 60,
                vendorID: 0x0002,
                productID: 0x0001
            ),
            DisplayPreset(
                id: "macbook-m1-13-scaled",
                name: "MacBook 经典 13 寸缩放 2880×1800（1440×900 HiDPI）",
                width: 2880,
                height: 1800,
                refreshRate: 60,
                vendorID: 0x0002,
                productID: 0x0002
            ),
            DisplayPreset(
                id: "oppo-pad-3",
                name: "OPPO Pad 3 2800×2000（1400×1000 HiDPI）",
                width: 2800,
                height: 2000,
                refreshRate: 60,
                vendorID: 0x0001,
                productID: 0x0001
            ),
        ]
    }

    private func showPresetEditor(preset: DisplayPreset?, completion: @escaping (DisplayPreset?) -> Void) {
        let alert = NSAlert()
        alert.messageText = preset == nil ? "添加分辨率" : "编辑分辨率"
        alert.informativeText = "输入分辨率名称、宽度、高度和刷新率（FPS）。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let nameField = NSTextField(frame: NSRect(x: 0, y: 96, width: 240, height: 22))
        let widthField = NSTextField(frame: NSRect(x: 0, y: 64, width: 240, height: 22))
        let heightField = NSTextField(frame: NSRect(x: 0, y: 32, width: 240, height: 22))
        let fpsField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))

        let nameLabel = NSTextField(labelWithString: "名称:")
        nameLabel.frame = NSRect(x: 0, y: 96, width: 60, height: 22)
        nameLabel.alignment = .right

        let widthLabel = NSTextField(labelWithString: "宽度:")
        widthLabel.frame = NSRect(x: 0, y: 64, width: 60, height: 22)
        widthLabel.alignment = .right

        let heightLabel = NSTextField(labelWithString: "高度:")
        heightLabel.frame = NSRect(x: 0, y: 32, width: 60, height: 22)
        heightLabel.alignment = .right

        let fpsLabel = NSTextField(labelWithString: "FPS:")
        fpsLabel.frame = NSRect(x: 0, y: 0, width: 60, height: 22)
        fpsLabel.alignment = .right

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 130))
        for view in [nameLabel, nameField, widthLabel, widthField, heightLabel, heightField, fpsLabel, fpsField] {
            container.addSubview(view)
        }
        nameField.frame.origin.x = 70
        widthField.frame.origin.x = 70
        heightField.frame.origin.x = 70
        fpsField.frame.origin.x = 70
        nameField.frame.size.width = 250
        widthField.frame.size.width = 250
        heightField.frame.size.width = 250
        fpsField.frame.size.width = 250

        alert.accessoryView = container

        if let preset = preset {
            nameField.stringValue = preset.name
            widthField.stringValue = String(preset.width)
            heightField.stringValue = String(preset.height)
            fpsField.stringValue = String(preset.refreshRate)
        } else {
            nameField.stringValue = ""
            widthField.stringValue = ""
            heightField.stringValue = ""
            fpsField.stringValue = "60"
        }

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            completion(nil)
            return
        }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let width = Int(widthField.stringValue),
              let height = Int(heightField.stringValue),
              let fps = Int(fpsField.stringValue),
              width > 0, height > 0, fps > 0 else {
            showError(message: "请填写有效的名称、正整数分辨率、正整数刷新率。")
            completion(nil)
            return
        }

        let id = preset?.id ?? UUID().uuidString
        let updated = DisplayPreset(
            id: id,
            name: name,
            width: width,
            height: height,
            refreshRate: fps,
            vendorID: 0x0001,
            productID: 0x0001
        )
        completion(updated)
    }

    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "输入错误"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
