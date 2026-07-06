import Cocoa
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    private let store = ConfigurationStore.shared
    private let engine = DisplayEngine.shared

    override init() {
        super.init()
        store.load()
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "VirtualDisplay")
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(configurationDidChangeExternally(_:)),
            name: NSNotification.Name(ConfigurationStore.configChangedNotificationName),
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.store.load()
            self.applyAllEnabledDisplays()
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

    @objc private func configurationDidChangeExternally(_ notification: Notification) {
        if let senderPID = notification.userInfo?["senderPID"] as? Int,
           senderPID == ProcessInfo.processInfo.processIdentifier {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.store.load()
            self.reconcileEngineWithConfiguration()
            self.applyAllEnabledDisplays()
        }
    }

    private func reconcileEngineWithConfiguration() {
        let enabledIDs = Set(store.configuration.displays.filter(\.isEnabled).map(\.id))
        for id in engine.activeDisplayIDs where !enabledIDs.contains(id) {
            engine.remove(configID: id)
        }
    }

    private func applyAllEnabledDisplays() {
        engine.applyAll(enabledConfigs: store.configuration.displays)
    }

    // MARK: - Display management

    @objc private func addDisplay(_: NSMenuItem) {
        let nextSerial = DisplayEngine.nextSerialNumber(for: store.configuration.displays)
        let defaultName = "VirtualDisplay_\(nextSerial)"

        let alert = NSAlert()
        alert.messageText = ""
        alert.informativeText = ""
        alert.alertStyle = .informational
        // 使用 NSAlert 原生左上角 APP 图标

        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 80))

        let titleLabel = NSTextField(labelWithString: "添加显示器")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.alignment = .center

        let descLabel = NSTextField(labelWithString: "输入新显示器的名称，仅支持字母、数字和下划线。")
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.preferredMaxLayoutWidth = 240

        let nameField = NSTextField()
        nameField.stringValue = defaultName
        nameField.placeholderString = "VirtualDisplay_2"
        nameField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let stack = NSStackView(views: [titleLabel, descLabel, nameField])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

        alert.accessoryView = container
        alert.window.initialFirstResponder = nameField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard DisplayEngine.isValidDisplayName(name) else {
            showError(message: "显示器名称不能为空，且只能包含字母、数字和下划线。")
            return
        }
        guard DisplayEngine.isDisplayNameUnique(name, in: store.configuration.displays) else {
            showError(message: "已存在名为「\(name)」的显示器，请使用其他名称。")
            return
        }

        let presets = DisplayEngine.defaultPresets()
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

        store.mutate { config in
            config.displays.append(newDisplay)
            config.selectedDisplayID = newDisplay.id
        }
        engine.apply(config: newDisplay, selecting: newDisplay.presets[0])
    }

    @objc private func renameDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }

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
        guard DisplayEngine.isValidDisplayName(name) else {
            showError(message: "显示器名称不能为空，且只能包含字母、数字和下划线。")
            return
        }
        guard DisplayEngine.isDisplayNameUnique(name, in: store.configuration.displays, excluding: payload.displayID) else {
            showError(message: "已存在名为「\(name)」的显示器，请使用其他名称。")
            return
        }

        store.mutate { config in
            guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
            config.displays[idx].name = name
        }
        if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
            engine.apply(config: updated)
        }
    }

    @objc private func deleteDisplay(_ sender: NSMenuItem) {
        guard store.configuration.displays.count > 1,
              let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }

        let alert = NSAlert()
        alert.messageText = "删除显示器"
        alert.informativeText = "确定要删除「\(display.name)」吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        engine.remove(configID: display.id)

        store.mutate { config in
            guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
            config.displays.remove(at: idx)
            if config.selectedDisplayID == display.id {
                let newIndex = min(idx, max(config.displays.count - 1, 0))
                config.selectedDisplayID = config.displays[newIndex].id
            }
        }
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let config = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }
        let isOnline = engine.isOnline(config)

        if isOnline {
            engine.remove(configID: config.id)
            store.mutate { configuration in
                guard let idx = configuration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                configuration.displays[idx].isEnabled = false
            }
        } else {
            store.mutate { configuration in
                guard let idx = configuration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                configuration.displays[idx].isEnabled = true
            }
            if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                engine.apply(config: updated)
            }
        }
    }

    // MARK: - Preset actions

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }

        store.mutate { config in
            guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
            if !config.displays[idx].multiResolutionMode {
                config.displays[idx].activePresetIDs = [preset.id]
            } else {
                if config.displays[idx].activePresetIDs.contains(preset.id) {
                    config.displays[idx].activePresetIDs.remove(preset.id)
                } else {
                    config.displays[idx].activePresetIDs.insert(preset.id)
                }
            }
        }

        if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
            engine.apply(config: updated, selecting: preset)
        }
    }

    @objc private func addPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload else { return }

        showPresetEditor(preset: nil) { [weak self] newPreset in
            guard let self = self, let newPreset = newPreset else { return }
            self.store.mutate { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                config.displays[idx].presets.append(newPreset)
                if !config.displays[idx].multiResolutionMode {
                    config.displays[idx].activePresetIDs = [newPreset.id]
                } else {
                    config.displays[idx].activePresetIDs.insert(newPreset.id)
                }
            }
            if let updated = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                self.engine.apply(config: updated, selecting: newPreset)
            }
        }
    }

    @objc private func editPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }
        showPresetEditor(preset: preset) { [weak self] updatedPreset in
            guard let self = self, let updated = updatedPreset else { return }
            self.store.mutate { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }),
                      let pIdx = config.displays[idx].presets.firstIndex(where: { $0.id == presetID }) else { return }
                config.displays[idx].presets[pIdx] = updated
            }
            if let updatedConfig = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                if updatedConfig.activePresetIDs.contains(updated.id) {
                    self.engine.apply(config: updatedConfig, selecting: updated)
                } else {
                    self.engine.apply(config: updatedConfig)
                }
            }
        }
    }

    @objc private func deletePreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }
        let alert = NSAlert()
        alert.messageText = "删除分辨率"
        alert.informativeText = "确定要删除「\(preset.name)」吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        store.mutate { config in
            guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }),
                  let pIdx = config.displays[idx].presets.firstIndex(where: { $0.id == presetID }) else { return }
            config.displays[idx].presets.remove(at: pIdx)
            config.displays[idx].activePresetIDs.remove(preset.id)

            if config.displays[idx].presets.isEmpty {
                let defaults = DisplayEngine.defaultPresets()
                config.displays[idx].presets = defaults
                config.displays[idx].activePresetIDs = [defaults[0].id]
            } else if config.displays[idx].activePresetIDs.isEmpty {
                config.displays[idx].activePresetIDs = [config.displays[idx].presets[0].id]
            }
        }

        if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
            engine.apply(config: updated)
        }
    }

    @objc private func restoreDefaultPresets(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload else { return }

        let alert = NSAlert()
        alert.messageText = "恢复默认预设"
        alert.informativeText = ""
        alert.alertStyle = .informational
        alert.addButton(withTitle: "恢复")
        alert.addButton(withTitle: "取消")

        // 照抄添加显示器的 accessoryView 布局：固定宽度容器 + 居中文本
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 60))

        let messageLabel = NSTextField(frame: NSRect(x: 40, y: 0, width: 240, height: 60))
        messageLabel.stringValue = "这将把当前显示器的所有分辨率预设恢复为内置默认值，并删除你添加的自定义预设。继续吗？"
        messageLabel.alignment = .center
        messageLabel.isEditable = false
        messageLabel.isBordered = false
        messageLabel.backgroundColor = .clear
        messageLabel.usesSingleLineMode = false
        messageLabel.cell?.wraps = true
        messageLabel.cell?.isScrollable = false
        messageLabel.lineBreakMode = .byWordWrapping
        container.addSubview(messageLabel)

        alert.accessoryView = container

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        store.mutate { config in
            guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
            let presets = DisplayEngine.defaultPresets()
            guard !presets.isEmpty else { return }
            config.displays[idx].presets = presets
            config.displays[idx].activePresetIDs = [presets[0].id]
        }

        if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
            engine.apply(config: updated)
        }
    }

    @objc private func toggleMultiResolutionMode(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload else { return }

        store.mutate { config in
            guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
            config.displays[idx].multiResolutionMode.toggle()

            if !config.displays[idx].multiResolutionMode && config.displays[idx].activePresetIDs.count > 1 {
                if let firstActiveID = config.displays[idx].presets.first(where: { config.displays[idx].activePresetIDs.contains($0.id) })?.id {
                    config.displays[idx].activePresetIDs = [firstActiveID]
                }
            }
        }

        if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
            engine.apply(config: updated)
        }
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

        for display in store.configuration.displays {
            let isOnline = engine.isOnline(display)

            let item = NSMenuItem(
                title: isOnline ? display.name : "\(display.name)（不可用）",
                action: nil,
                keyEquivalent: ""
            )
            item.submenu = makeDisplayMenu(config: display)
            item.state = isOnline ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let versionItem = NSMenuItem(title: "版本 \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        return menu
    }

    private func makeDisplayMenu(config: VirtualDisplayConfig) -> NSMenu {
        let menu = NSMenu()
        let isOnline = engine.isOnline(config)

        for preset in config.presets {
            menu.addItem(makePresetItem(preset: preset, config: config))
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

        let toggleItem = NSMenuItem(
            title: isOnline ? "关闭显示器" : "开启显示器",
            action: #selector(toggleDisplay(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(toggleItem)

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
        if store.configuration.displays.count <= 1 {
            deleteItem.isEnabled = false
        }
        menu.addItem(deleteItem)

        return menu
    }

    private func makePresetItem(preset: DisplayPreset, config: VirtualDisplayConfig) -> NSMenuItem {
        let payload = MenuPayload(displayID: config.id, presetID: preset.id)
        let item = NSMenuItem(
            title: preset.name,
            action: #selector(presetSelected(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = payload
        if config.activePresetIDs.contains(preset.id) {
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
        let widthString = widthField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let heightString = heightField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let fpsString = fpsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let width = Int(widthString),
              let height = Int(heightString),
              let fps = Int(fpsString),
              width > 0, height > 0, fps > 0 else {
            showError(message: "请填写有效的名称、正整数分辨率、正整数刷新率。")
            completion(nil)
            return
        }
        guard width % 2 == 0, height % 2 == 0 else {
            showError(message: "HiDPI 模式下宽度和高度必须为偶数。")
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
