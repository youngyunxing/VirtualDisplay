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

        DispatchQueue.main.async { [weak self] in
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

    private func apply(config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset? = nil) {
        _ = engine.apply(config: config, selecting: selectedPreset)
    }

    private func showDisplayNameEditor(title: String, description: String, defaultName: String, excludingDisplayID: String? = nil, completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = ""
        alert.informativeText = ""
        alert.alertStyle = .informational
        // 使用 NSAlert 原生左上角 APP 图标
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 110))

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.alignment = .center

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.preferredMaxLayoutWidth = 240

        let nameField = NSTextField()
        nameField.stringValue = defaultName
        nameField.placeholderString = "VirtualDisplay_1"
        nameField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.preferredMaxLayoutWidth = 240
        errorLabel.usesSingleLineMode = false
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.cell?.wraps = true
        errorLabel.cell?.isScrollable = false
        errorLabel.isHidden = true

        let stack = NSStackView(views: [titleLabel, descLabel, nameField, errorLabel])
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

        while true {
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else {
                completion(nil)
                return
            }

            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            var errorMessage: String?
            if !DisplayEngine.isValidDisplayName(name) {
                errorMessage = "显示器名称不能为空，且只能包含字母、数字和下划线。"
            } else if !DisplayEngine.isDisplayNameUnique(name, in: store.configuration.displays, excluding: excludingDisplayID) {
                errorMessage = "已存在名为「\(name)」的显示器，请使用其他名称。"
            }

            if let message = errorMessage {
                errorLabel.stringValue = message
                errorLabel.isHidden = false
                continue
            }

            completion(name)
            return
        }
    }

    // MARK: - Display management

    @objc private func addDisplay(_: NSMenuItem) {
        let nextSerial = DisplayEngine.nextSerialNumber(for: store.configuration.displays)
        let defaultName = "VirtualDisplay_\(nextSerial)"

        showDisplayNameEditor(
            title: "添加显示器",
            description: "输入新显示器的名称，仅支持字母、数字和下划线。",
            defaultName: defaultName
        ) { [weak self] name in
            guard let self = self, let name = name else { return }

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

            self.store.mutate { config in
                config.displays.append(newDisplay)
                config.selectedDisplayID = newDisplay.id
            }
            self.apply(config: newDisplay, selecting: newDisplay.presets[0])
        }
    }

    @objc private func renameDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }

        showDisplayNameEditor(
            title: "重命名显示器",
            description: "输入新的显示器名称，仅支持字母、数字和下划线。",
            defaultName: display.name,
            excludingDisplayID: payload.displayID
        ) { [weak self] name in
            guard let self = self, let name = name else { return }

            self.store.mutate { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                config.displays[idx].name = name
            }
            if let updated = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                self.apply(config: updated)
            }
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
                apply(config: updated)
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
            apply(config: updated, selecting: preset)
        }
    }

    @objc private func addPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload else { return }

        showPresetEditor(displayID: payload.displayID, preset: nil) { [weak self] newPreset in
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
                self.apply(config: updated, selecting: newPreset)
            }
        }
    }

    @objc private func editPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }
        showPresetEditor(displayID: payload.displayID, preset: preset) { [weak self] updatedPreset in
            guard let self = self, let updated = updatedPreset else { return }
            self.store.mutate { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }),
                      let pIdx = config.displays[idx].presets.firstIndex(where: { $0.id == presetID }) else { return }
                config.displays[idx].presets[pIdx] = updated
            }
            if let updatedConfig = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                if updatedConfig.activePresetIDs.contains(updated.id) {
                    self.apply(config: updatedConfig, selecting: updated)
                } else {
                    self.apply(config: updatedConfig)
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
            apply(config: updated)
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
            apply(config: updated)
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
            apply(config: updated)
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
            menu.addItem(makeDisplayItem(config: display))
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

        if let error = engine.lastError(for: config.id) {
            let notice = NSMenuItem(title: "⚠ \(error.localizedDescription)", action: nil, keyEquivalent: "")
            notice.isEnabled = false
            notice.attributedTitle = NSAttributedString(
                string: "⚠ \(error.localizedDescription)",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
            menu.addItem(notice)
            menu.addItem(NSMenuItem.separator())
        } else if !isOnline {
            let notice = NSMenuItem(title: "⚠ 当前显示器已关闭", action: nil, keyEquivalent: "")
            notice.isEnabled = false
            notice.attributedTitle = NSAttributedString(
                string: "⚠ 当前显示器已关闭",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
            menu.addItem(notice)
            menu.addItem(NSMenuItem.separator())
        }

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
        let failedIDs = engine.failedPresetIDs(for: config.id)
        let hasError = engine.lastError(for: config.id) != nil || failedIDs.contains(preset.id)

        let logicalWidth = preset.width / 2
        let logicalHeight = preset.height / 2
        let baseTitle = "\(preset.name) (\(preset.width)×\(preset.height)@\(preset.refreshRate) / \(logicalWidth)×\(logicalHeight) HiDPI)"

        let item = NSMenuItem(
            title: baseTitle,
            action: #selector(presetSelected(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = payload
        if config.activePresetIDs.contains(preset.id) {
            item.state = .on
        }

        if hasError {
            item.attributedTitle = NSAttributedString(
                string: "\(baseTitle) ⚠",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
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

    private func displayTitle(name: String, isOnline: Bool, error: DisplayEngineError? = nil) -> NSAttributedString {
        let hasError = error != nil
        let suffix: String
        if !isOnline {
            suffix = "（已关闭）"
        } else if hasError {
            suffix = "（应用失败）"
        } else {
            suffix = ""
        }
        let text = name + suffix
        let color: NSColor = (isOnline && !hasError) ? .labelColor : .secondaryLabelColor
        return NSAttributedString(
            string: text,
            attributes: [.foregroundColor: color]
        )
    }

    private func makeDisplayItem(config: VirtualDisplayConfig) -> NSMenuItem {
        let isOnline = engine.isOnline(config)
        let error = engine.lastError(for: config.id)
        let item = NSMenuItem()
        item.attributedTitle = displayTitle(name: config.name, isOnline: isOnline, error: error)
        item.state = (isOnline && error == nil) ? .on : .off
        item.submenu = makeDisplayMenu(config: config)
        return item
    }

    // MARK: - Editors / Alerts

    private func showPresetEditor(displayID: String, preset: DisplayPreset?, completion: @escaping (DisplayPreset?) -> Void) {
        guard let display = store.configuration.displays.first(where: { $0.id == displayID }) else {
            completion(nil)
            return
        }

        let alert = NSAlert()
        alert.messageText = ""
        alert.informativeText = ""
        alert.alertStyle = .informational
        // 使用 NSAlert 原生左上角 APP 图标
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 200))

        let titleLabel = NSTextField(labelWithString: preset == nil ? "添加分辨率" : "编辑分辨率")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.alignment = .center

        let descLabel = NSTextField(labelWithString: "输入分辨率名称、宽度、高度和刷新率（FPS）。")
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.preferredMaxLayoutWidth = 240

        let nameField = NSTextField()
        nameField.placeholderString = "4K UHD"
        nameField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let widthField = NSTextField()
        widthField.placeholderString = "3840"
        widthField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let heightField = NSTextField()
        heightField.placeholderString = "2160"
        heightField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let fpsField = NSTextField()
        fpsField.placeholderString = "60"
        fpsField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.preferredMaxLayoutWidth = 240
        errorLabel.usesSingleLineMode = false
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.cell?.wraps = true
        errorLabel.cell?.isScrollable = false
        errorLabel.isHidden = true

        func makeRow(label: String, field: NSTextField) -> NSStackView {
            let labelView = NSTextField(labelWithString: label)
            labelView.alignment = .right
            labelView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            labelView.widthAnchor.constraint(equalToConstant: 50).isActive = true

            let row = NSStackView(views: [labelView, field])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.distribution = .fill
            return row
        }

        let formStack = NSStackView(views: [
            makeRow(label: "名称:", field: nameField),
            makeRow(label: "宽度:", field: widthField),
            makeRow(label: "高度:", field: heightField),
            makeRow(label: "FPS:", field: fpsField)
        ])
        formStack.orientation = .vertical
        formStack.alignment = .centerX
        formStack.spacing = 6

        let stack = NSStackView(views: [titleLabel, descLabel, formStack, errorLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

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

        alert.accessoryView = container
        alert.window.initialFirstResponder = nameField

        while true {
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else {
                completion(nil)
                return
            }

            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let widthString = widthField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let heightString = heightField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let fpsString = fpsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

            var errorMessage: String?
            if name.isEmpty {
                errorMessage = "名称不能为空。"
            } else if let existing = display.presets.first(where: { $0.name == name && $0.id != preset?.id }) {
                errorMessage = "该显示器下已存在名为「\(name)」的预设。"
            } else if widthString.isEmpty || heightString.isEmpty || fpsString.isEmpty {
                errorMessage = "宽度、高度、刷新率均不能为空。"
            } else if Int(widthString) == nil || Int(heightString) == nil || Int(fpsString) == nil {
                errorMessage = "宽度、高度、刷新率必须为正整数（仅支持数字）。"
            } else if let width = Int(widthString), let height = Int(heightString), let fps = Int(fpsString) {
                if width <= 0 || height <= 0 || fps <= 0 {
                    errorMessage = "宽度、高度、刷新率必须大于 0。"
                } else if width % 2 != 0 || height % 2 != 0 {
                    errorMessage = "HiDPI 模式下宽度和高度必须为偶数。"
                }
            }

            if let message = errorMessage {
                errorLabel.stringValue = message
                errorLabel.isHidden = false
                continue
            }

            let id = preset?.id ?? UUID().uuidString
            let updated = DisplayPreset(
                id: id,
                name: name,
                width: Int(widthString)!,
                height: Int(heightString)!,
                refreshRate: Int(fpsString)!,
                vendorID: 0x0001,
                productID: 0x0001
            )
            completion(updated)
            return
        }
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style = .critical) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
