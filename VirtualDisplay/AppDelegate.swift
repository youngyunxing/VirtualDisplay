import Cocoa
import CoreGraphics

struct DisplayPreset: Codable, Identifiable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let refreshRate: Int
    let vendorID: UInt32
    let productID: UInt32
}

struct VirtualDisplayConfig: Codable, Identifiable {
    let id: String
    var name: String
    var presets: [DisplayPreset]
    var activePresetIDs: Set<String>
    var multiResolutionMode: Bool
    var serialNumber: UInt32
    var vendorID: UInt32
    var productID: UInt32
}

struct AppConfiguration: Codable {
    var version: Int
    var displays: [VirtualDisplayConfig]
    var selectedDisplayID: String?
}

private final class MenuPayload: NSObject {
    let displayID: String
    let presetID: String?

    init(displayID: String, presetID: String? = nil) {
        self.displayID = displayID
        self.presetID = presetID
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let appConfigurationKey = "appConfigurationV2"

    var statusItem: NSStatusItem!

    private var appConfiguration: AppConfiguration {
        didSet {
            saveAppConfiguration()
        }
    }

    private var activeDisplays: [String: CGVirtualDisplay] = [:]
    private var displayMaxPixels: [String: (width: Int, height: Int)] = [:]
    private var appliedDisplayNames: [String: String] = [:]
    private var lastOrderedPresetIDs: [String: [String]] = [:]

    override init() {
        if let data = UserDefaults.standard.data(forKey: appConfigurationKey),
           let config = try? JSONDecoder().decode(AppConfiguration.self, from: data),
           !config.displays.isEmpty {
            appConfiguration = config
        } else {
            let defaultDisplay = Self.defaultDisplayConfig()
            appConfiguration = AppConfiguration(
                version: 2,
                displays: [defaultDisplay],
                selectedDisplayID: defaultDisplay.id
            )
        }

        var selectedID = appConfiguration.selectedDisplayID
        if selectedID == nil || !appConfiguration.displays.contains(where: { $0.id == selectedID }) {
            selectedID = appConfiguration.displays.first?.id
        }
        appConfiguration.selectedDisplayID = selectedID

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
            guard let self = self else { return }
            for config in self.appConfiguration.displays {
                self.applySettings(for: config)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return false
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func statusBarButtonClicked(_: Any?) {
        statusItem.popUpMenu(buildMenu())
    }

    // MARK: - Display management

    @objc private func addDisplay(_: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "添加显示器"
        alert.informativeText = "输入新显示器的名称，仅支持字母、数字和下划线。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        let nextSerial = (appConfiguration.displays.map(\.serialNumber).max() ?? 0) + 1
        nameField.stringValue = "VirtualDisplay_\(nextSerial)"
        nameField.placeholderString = "VirtualDisplay_2"
        alert.accessoryView = nameField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidDisplayName(name) else {
            showError(message: "显示器名称不能为空，且只能包含字母、数字和下划线。")
            return
        }

        let presets = Self.defaultPresets()
        let newDisplay = VirtualDisplayConfig(
            id: UUID().uuidString,
            name: name,
            presets: presets,
            activePresetIDs: [presets[0].id],
            multiResolutionMode: false,
            serialNumber: nextSerial,
            vendorID: 0x0001,
            productID: nextSerial
        )

        appConfiguration.displays.append(newDisplay)
        applySettings(for: newDisplay, selecting: newDisplay.presets[0])
    }

    @objc private func renameDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let index = appConfiguration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
        let display = appConfiguration.displays[index]

        let alert = NSAlert()
        alert.messageText = "重命名显示器"
        alert.informativeText = "输入新的显示器名称，仅支持字母、数字和下划线。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        nameField.stringValue = display.name
        nameField.placeholderString = "VirtualDisplay_1"
        alert.accessoryView = nameField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidDisplayName(name) else {
            showError(message: "显示器名称不能为空，且只能包含字母、数字和下划线。")
            return
        }

        appConfiguration.displays[index].name = name
        applySettings(for: appConfiguration.displays[index])
    }

    private static func isValidDisplayName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let range = NSRange(location: 0, length: name.utf16.count)
        let regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9_]+$")
        return regex?.firstMatch(in: name, options: [], range: range) != nil
    }

    @objc private func deleteDisplay(_ sender: NSMenuItem) {
        guard appConfiguration.displays.count > 1,
              let payload = sender.representedObject as? MenuPayload,
              let index = appConfiguration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
        let display = appConfiguration.displays[index]

        let alert = NSAlert()
        alert.messageText = "删除显示器"
        alert.informativeText = "确定要删除「\(display.name)」吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        activeDisplays.removeValue(forKey: display.id)
        displayMaxPixels.removeValue(forKey: display.id)
        appliedDisplayNames.removeValue(forKey: display.id)
        lastOrderedPresetIDs.removeValue(forKey: display.id)

        appConfiguration.displays.remove(at: index)

        if appConfiguration.selectedDisplayID == display.id {
            let newIndex = min(index, max(appConfiguration.displays.count - 1, 0))
            appConfiguration.selectedDisplayID = appConfiguration.displays[newIndex].id
        }
    }

    // MARK: - Preset actions

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let index = appConfiguration.displays.firstIndex(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = appConfiguration.displays[index].presets.first(where: { $0.id == presetID }) else { return }

        if !appConfiguration.displays[index].multiResolutionMode {
            appConfiguration.displays[index].activePresetIDs = [preset.id]
        } else {
            if appConfiguration.displays[index].activePresetIDs.contains(preset.id) {
                appConfiguration.displays[index].activePresetIDs.remove(preset.id)
            } else {
                appConfiguration.displays[index].activePresetIDs.insert(preset.id)
            }
        }

        applySettings(for: appConfiguration.displays[index], selecting: preset)
    }

    @objc private func addPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let index = appConfiguration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }

        showPresetEditor(preset: nil) { [weak self] newPreset in
            guard let self = self, let newPreset = newPreset else { return }
            self.appConfiguration.displays[index].presets.append(newPreset)
            if !self.appConfiguration.displays[index].multiResolutionMode {
                self.appConfiguration.displays[index].activePresetIDs = [newPreset.id]
            } else {
                self.appConfiguration.displays[index].activePresetIDs.insert(newPreset.id)
            }
            self.applySettings(for: self.appConfiguration.displays[index], selecting: newPreset)
        }
    }

    @objc private func editPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let index = appConfiguration.displays.firstIndex(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let presetIndex = appConfiguration.displays[index].presets.firstIndex(where: { $0.id == presetID }) else { return }

        let preset = appConfiguration.displays[index].presets[presetIndex]
        showPresetEditor(preset: preset) { [weak self] updatedPreset in
            guard let self = self, let updated = updatedPreset else { return }
            self.appConfiguration.displays[index].presets[presetIndex] = updated
            if self.appConfiguration.displays[index].activePresetIDs.contains(updated.id) {
                self.applySettings(for: self.appConfiguration.displays[index], selecting: updated)
            } else {
                self.applySettings(for: self.appConfiguration.displays[index])
            }
        }
    }

    @objc private func deletePreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let index = appConfiguration.displays.firstIndex(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let presetIndex = appConfiguration.displays[index].presets.firstIndex(where: { $0.id == presetID }) else { return }

        let preset = appConfiguration.displays[index].presets[presetIndex]
        let alert = NSAlert()
        alert.messageText = "删除分辨率"
        alert.informativeText = "确定要删除「\(preset.name)」吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        appConfiguration.displays[index].presets.remove(at: presetIndex)
        appConfiguration.displays[index].activePresetIDs.remove(preset.id)

        if appConfiguration.displays[index].presets.isEmpty {
            let defaults = Self.defaultPresets()
            appConfiguration.displays[index].presets = defaults
            appConfiguration.displays[index].activePresetIDs = [defaults[0].id]
        } else if appConfiguration.displays[index].activePresetIDs.isEmpty {
            appConfiguration.displays[index].activePresetIDs = [appConfiguration.displays[index].presets[0].id]
        }

        applySettings(for: appConfiguration.displays[index])
    }

    @objc private func restoreDefaultPresets(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let index = appConfiguration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }

        let alert = NSAlert()
        alert.messageText = "恢复默认预设"
        alert.informativeText = "这将恢复当前显示器的所有内置分辨率预设，但保留你已添加的自定义预设。继续吗？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "恢复")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let defaultIDs = Set(Self.defaultPresets().map(\.id))
        let customPresets = appConfiguration.displays[index].presets.filter { !defaultIDs.contains($0.id) }
        appConfiguration.displays[index].presets = Self.defaultPresets() + customPresets
        applySettings(for: appConfiguration.displays[index])
    }

    @objc private func toggleMultiResolutionMode(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let index = appConfiguration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
        appConfiguration.displays[index].multiResolutionMode.toggle()

        if !appConfiguration.displays[index].multiResolutionMode && appConfiguration.displays[index].activePresetIDs.count > 1 {
            if let firstActiveID = appConfiguration.displays[index].presets.first(where: { appConfiguration.displays[index].activePresetIDs.contains($0.id) })?.id {
                appConfiguration.displays[index].activePresetIDs = [firstActiveID]
            }
        }

        applySettings(for: appConfiguration.displays[index])
    }

    // MARK: - Menu building

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let addDisplayItem = NSMenuItem(
            title: "添加显示器...",
            action: #selector(addDisplay(_:)),
            keyEquivalent: ""
        )
        addDisplayItem.target = self
        menu.addItem(addDisplayItem)

        menu.addItem(NSMenuItem.separator())

        for display in appConfiguration.displays {
            let item = NSMenuItem(
                title: display.name,
                action: nil,
                keyEquivalent: ""
            )
            item.submenu = makeDisplayMenu(config: display)
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        return menu
    }

    private func makeDisplayMenu(config: VirtualDisplayConfig) -> NSMenu {
        let menu = NSMenu()

        for preset in config.presets {
            menu.addItem(makePresetItem(preset: preset, displayID: config.id))
        }

        menu.addItem(NSMenuItem.separator())

        let multiModeItem = NSMenuItem(
            title: "多分辨率模式",
            action: #selector(toggleMultiResolutionMode(_:)),
            keyEquivalent: ""
        )
        multiModeItem.target = self
        multiModeItem.state = config.multiResolutionMode ? .on : .off
        multiModeItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(multiModeItem)

        menu.addItem(NSMenuItem.separator())

        let addPresetItem = NSMenuItem(
            title: "添加分辨率...",
            action: #selector(addPreset(_:)),
            keyEquivalent: ""
        )
        addPresetItem.target = self
        addPresetItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(addPresetItem)

        let restoreItem = NSMenuItem(
            title: "恢复默认预设",
            action: #selector(restoreDefaultPresets(_:)),
            keyEquivalent: ""
        )
        restoreItem.target = self
        restoreItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

        let renameItem = NSMenuItem(
            title: "重命名显示器",
            action: #selector(renameDisplay(_:)),
            keyEquivalent: ""
        )
        renameItem.target = self
        renameItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(renameItem)

        let deleteItem = NSMenuItem(
            title: "删除显示器",
            action: #selector(deleteDisplay(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.representedObject = MenuPayload(displayID: config.id)
        if appConfiguration.displays.count <= 1 {
            deleteItem.isEnabled = false
        }
        menu.addItem(deleteItem)

        return menu
    }

    private func makePresetItem(preset: DisplayPreset, displayID: String) -> NSMenuItem {
        let payload = MenuPayload(displayID: displayID, presetID: preset.id)
        let item = NSMenuItem(
            title: preset.name,
            action: #selector(presetSelected(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = payload
        if let config = appConfiguration.displays.first(where: { $0.id == displayID }),
           config.activePresetIDs.contains(preset.id) {
            item.state = .on
        }

        let submenu = NSMenu()

        let editItem = NSMenuItem(
            title: "编辑...",
            action: #selector(editPreset(_:)),
            keyEquivalent: ""
        )
        editItem.target = self
        editItem.representedObject = payload
        submenu.addItem(editItem)

        let deleteItem = NSMenuItem(
            title: "删除",
            action: #selector(deletePreset(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.representedObject = payload
        submenu.addItem(deleteItem)

        item.submenu = submenu

        return item
    }

    // MARK: - Display application

    private func applySettings(for config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset? = nil) {
        guard let index = appConfiguration.displays.firstIndex(where: { $0.id == config.id }) else { return }

        // Normalize active preset IDs.
        var validIDs = config.activePresetIDs.filter { id in config.presets.contains(where: { $0.id == id }) }
        if validIDs.isEmpty {
            validIDs = [config.presets[0].id]
        }
        if !config.multiResolutionMode && validIDs.count > 1 {
            validIDs = [validIDs.first!]
        }
        if validIDs != config.activePresetIDs {
            appConfiguration.displays[index].activePresetIDs = validIDs
        }

        let liveConfig = appConfiguration.displays[index]
        let activePresets = liveConfig.presets.filter { liveConfig.activePresetIDs.contains($0.id) }

        var orderedPresets = activePresets
        if let selected = selectedPreset,
           let selectedIndex = orderedPresets.firstIndex(where: { $0.id == selected.id }) {
            orderedPresets.swapAt(0, selectedIndex)
        }

        let orderedIDs = orderedPresets.map(\.id)

        let requiredMaxWidth = liveConfig.presets.map(\.width).max() ?? liveConfig.presets[0].width
        let requiredMaxHeight = liveConfig.presets.map(\.height).max() ?? liveConfig.presets[0].height

        let existingMax = displayMaxPixels[liveConfig.id]
        let needsRecreate = activeDisplays[liveConfig.id] == nil
            || (existingMax?.width ?? 0) < requiredMaxWidth
            || (existingMax?.height ?? 0) < requiredMaxHeight
            || appliedDisplayNames[liveConfig.id] != liveConfig.name

        if !needsRecreate && orderedIDs == lastOrderedPresetIDs[liveConfig.id] {
            return
        }
        lastOrderedPresetIDs[liveConfig.id] = orderedIDs

        if needsRecreate {
            activeDisplays.removeValue(forKey: liveConfig.id)

            let descriptor = CGVirtualDisplayDescriptor()
            descriptor.setDispatchQueue(DispatchQueue.main)
            descriptor.name = liveConfig.name
            descriptor.maxPixelsWide = UInt32(requiredMaxWidth)
            descriptor.maxPixelsHigh = UInt32(requiredMaxHeight)
            descriptor.vendorID = liveConfig.vendorID
            descriptor.productID = liveConfig.productID
            descriptor.serialNumber = liveConfig.serialNumber

            let display = CGVirtualDisplay(descriptor: descriptor)
            activeDisplays[liveConfig.id] = display
            displayMaxPixels[liveConfig.id] = (requiredMaxWidth, requiredMaxHeight)
            appliedDisplayNames[liveConfig.id] = liveConfig.name
            disableMirroring(for: display.displayID)
        }

        guard let display = activeDisplays[liveConfig.id] else { return }

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

    private func disableMirroring(for displayID: CGDirectDisplayID) {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        CGConfigureDisplayMirrorOfDisplay(config, displayID, CGDirectDisplayID(0))
        _ = CGCompleteDisplayConfiguration(config, .forSession)
    }

    // MARK: - Persistence

    private func saveAppConfiguration() {
        if let data = try? JSONEncoder().encode(appConfiguration) {
            UserDefaults.standard.set(data, forKey: appConfigurationKey)
        }
    }

    // MARK: - Defaults

    private static func defaultDisplayConfig() -> VirtualDisplayConfig {
        let presets = defaultPresets()
        return VirtualDisplayConfig(
            id: UUID().uuidString,
            name: "VirtualDisplay",
            presets: presets,
            activePresetIDs: [presets[0].id],
            multiResolutionMode: false,
            serialNumber: 1,
            vendorID: 0x0001,
            productID: 0x0001
        )
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

    // MARK: - Editors / Alerts

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
