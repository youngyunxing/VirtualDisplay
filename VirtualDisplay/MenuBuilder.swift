import Cocoa

final class MenuBuilder {
    private let store: ConfigurationStore
    private let engine: DisplayEngine

    init(store: ConfigurationStore, engine: DisplayEngine) {
        self.store = store
        self.engine = engine
    }

    func buildMenu(target: DisplayActionHandler) -> NSMenu {
        let menu = NSMenu()

        for display in store.configuration.displays {
            menu.addItem(makeDisplayItem(config: display, target: target))
        }

        menu.addItem(NSMenuItem.separator())

        let addDisplayItem = NSMenuItem(
            title: "添加显示器",
            action: #selector(DisplayActionHandler.addDisplay(_:)),
            keyEquivalent: ""
        )
        addDisplayItem.target = target
        menu.addItem(addDisplayItem)

        let importItem = NSMenuItem(
            title: "导入配置",
            action: #selector(DisplayActionHandler.importConfiguration(_:)),
            keyEquivalent: ""
        )
        importItem.target = target
        menu.addItem(importItem)

        menu.addItem(NSMenuItem.separator())

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let versionItem = NSMenuItem(title: "版本 \(version)", action: #selector(DisplayActionHandler.showVersion(_:)), keyEquivalent: "")
        versionItem.target = target
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(title: "退出", action: #selector(DisplayActionHandler.quitApp), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }

    func makeDisplayMenu(config: VirtualDisplayConfig, target: DisplayActionHandler) -> NSMenu {
        let menu = NSMenu()
        let isOnline = engine.isOnline(config)
        let error = engine.lastError(for: config.id)

        // 顶部标题栏：显示器名 + 状态 pill
        let headerItem = NSMenuItem()
        headerItem.attributedTitle = displayHeaderTitle(
            name: config.name,
            isOnline: isOnline,
            error: error
        )
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        if let error = error {
            let errorItem = NSMenuItem(
                title: error.localizedDescription,
                action: nil,
                keyEquivalent: ""
            )
            errorItem.isEnabled = false
            errorItem.attributedTitle = NSAttributedString(
                string: error.localizedDescription,
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
            menu.addItem(errorItem)
        }

        menu.addItem(NSMenuItem.separator())

        for preset in config.presets {
            menu.addItem(makePresetItem(preset: preset, config: config, target: target))
        }

        menu.addItem(NSMenuItem.separator())

        let multiModeItem = NSMenuItem(
            title: "多分辨率模式",
            action: #selector(DisplayActionHandler.toggleMultiResolutionMode(_:)),
            keyEquivalent: ""
        )
        multiModeItem.target = target
        multiModeItem.state = config.multiResolutionMode ? .on : .off
        multiModeItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(multiModeItem)

        menu.addItem(NSMenuItem.separator())

        let addPresetItem = NSMenuItem(
            title: "添加分辨率",
            action: #selector(DisplayActionHandler.addPreset(_:)),
            keyEquivalent: ""
        )
        addPresetItem.target = target
        addPresetItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(addPresetItem)

        let restoreItem = NSMenuItem(
            title: "恢复默认预设",
            action: #selector(DisplayActionHandler.restoreDefaultPresets(_:)),
            keyEquivalent: ""
        )
        restoreItem.target = target
        restoreItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(
            title: isOnline ? "关闭显示器" : "开启显示器",
            action: #selector(DisplayActionHandler.toggleDisplay(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = target
        toggleItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(toggleItem)

        let refreshItem = NSMenuItem(
            title: "刷新显示器",
            action: #selector(DisplayActionHandler.refreshDisplay(_:)),
            keyEquivalent: ""
        )
        refreshItem.target = target
        refreshItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(refreshItem)

        let deleteItem = NSMenuItem(
            title: "删除显示器",
            action: #selector(DisplayActionHandler.deleteDisplay(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = target
        deleteItem.representedObject = MenuPayload(displayID: config.id)
        if store.configuration.displays.count <= 1 {
            deleteItem.isEnabled = false
        }
        menu.addItem(deleteItem)

        let renameItem = NSMenuItem(
            title: "重命名显示器",
            action: #selector(DisplayActionHandler.renameDisplay(_:)),
            keyEquivalent: ""
        )
        renameItem.target = target
        renameItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(renameItem)

        let exportDisplayItem = NSMenuItem(
            title: "导出此显示器配置",
            action: #selector(DisplayActionHandler.exportDisplay(_:)),
            keyEquivalent: ""
        )
        exportDisplayItem.target = target
        exportDisplayItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(exportDisplayItem)

        return menu
    }

    func makePresetItem(preset: DisplayPreset, config: VirtualDisplayConfig, target: DisplayActionHandler) -> NSMenuItem {
        let payload = MenuPayload(displayID: config.id, presetID: preset.id)
        let failedIDs = engine.failedPresetIDs(for: config.id)
        let hasError = engine.lastError(for: config.id) != nil || failedIDs.contains(preset.id)
        let isActive = config.activePresetIDs.contains(preset.id)

        let logicalWidth = preset.width / 2
        let logicalHeight = preset.height / 2
        let baseTitle = "\(preset.name) (\(preset.width)×\(preset.height)@\(preset.refreshRate) / \(logicalWidth)×\(logicalHeight) HiDPI)"
        let isCurrentOutput = config.multiResolutionMode
            && engine.currentPreset(for: config)?.id == preset.id

        let item = NSMenuItem(
            title: baseTitle,
            action: #selector(DisplayActionHandler.presetSelected(_:)),
            keyEquivalent: ""
        )
        item.target = target
        item.representedObject = payload
        if isActive {
            item.state = .on
        }

        var titleAttributes: [NSAttributedString.Key: Any] = [:]
        if hasError {
            titleAttributes[.foregroundColor] = NSColor.secondaryLabelColor
        } else if isCurrentOutput {
            titleAttributes[.foregroundColor] = NSColor.systemGreen
        }

        if !titleAttributes.isEmpty {
            item.attributedTitle = NSAttributedString(string: baseTitle, attributes: titleAttributes)
        }

        let submenu = NSMenu()

        let editItem = NSMenuItem(
            title: "编辑",
            action: #selector(DisplayActionHandler.editPreset(_:)),
            keyEquivalent: ""
        )
        editItem.target = target
        editItem.representedObject = payload
        submenu.addItem(editItem)

        let deleteItem = NSMenuItem(
            title: "删除",
            action: #selector(DisplayActionHandler.deletePreset(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = target
        deleteItem.representedObject = payload
        submenu.addItem(deleteItem)

        let exportPresetItem = NSMenuItem(
            title: "导出",
            action: #selector(DisplayActionHandler.exportPreset(_:)),
            keyEquivalent: ""
        )
        exportPresetItem.target = target
        exportPresetItem.representedObject = payload
        submenu.addItem(exportPresetItem)

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

    private func displayHeaderTitle(name: String, isOnline: Bool, error: DisplayEngineError?) -> NSAttributedString {
        let statusText: String
        let pillColor: NSColor
        let noteText: String?
        if error != nil {
            statusText = "应用失败"
            pillColor = .systemRed
            noteText = "可在下方刷新"
        } else if isOnline {
            statusText = "在线"
            pillColor = .systemGreen
            noteText = nil
        } else {
            statusText = "已关闭"
            pillColor = .secondaryLabelColor
            noteText = "可在下方开启"
        }

        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let smallFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)

        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let separatorAttributes: [NSAttributedString.Key: Any] = [
            .font: smallFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let pillAttributes: [NSAttributedString.Key: Any] = [
            .font: smallFont,
            .foregroundColor: pillColor
        ]
        let noteAttributes: [NSAttributedString.Key: Any] = [
            .font: smallFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let result = NSMutableAttributedString(string: name, attributes: nameAttributes)
        result.append(NSAttributedString(string: "  ", attributes: separatorAttributes))
        result.append(NSAttributedString(string: "● ", attributes: pillAttributes))
        result.append(NSAttributedString(string: statusText, attributes: pillAttributes))
        if let note = noteText {
            result.append(NSAttributedString(string: " · ", attributes: separatorAttributes))
            result.append(NSAttributedString(string: note, attributes: noteAttributes))
        }
        return result
    }

    func makeDisplayItem(config: VirtualDisplayConfig, target: DisplayActionHandler) -> NSMenuItem {
        let isOnline = engine.isOnline(config)
        let error = engine.lastError(for: config.id)
        let item = NSMenuItem()
        item.attributedTitle = displayTitle(name: config.name, isOnline: isOnline, error: error)
        item.state = (isOnline && error == nil) ? .on : .off
        item.submenu = makeDisplayMenu(config: config, target: target)
        return item
    }
}
