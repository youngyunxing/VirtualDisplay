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

        let addDisplayItem = NSMenuItem(
            title: "添加显示器...",
            action: #selector(DisplayActionHandler.addDisplay(_:)),
            keyEquivalent: ""
        )
        addDisplayItem.target = target
        menu.addItem(addDisplayItem)

        menu.addItem(NSMenuItem.separator())

        for display in store.configuration.displays {
            menu.addItem(makeDisplayItem(config: display, target: target))
        }

        menu.addItem(NSMenuItem.separator())

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let versionItem = NSMenuItem(title: "版本 \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem(title: "退出", action: #selector(DisplayActionHandler.quitApp), keyEquivalent: "q"))

        return menu
    }

    func makeDisplayMenu(config: VirtualDisplayConfig, target: DisplayActionHandler) -> NSMenu {
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
            title: "添加分辨率...",
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

        let renameItem = NSMenuItem(
            title: "重命名显示器",
            action: #selector(DisplayActionHandler.renameDisplay(_:)),
            keyEquivalent: ""
        )
        renameItem.target = target
        renameItem.representedObject = MenuPayload(displayID: config.id)
        menu.addItem(renameItem)

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

        return menu
    }

    func makePresetItem(preset: DisplayPreset, config: VirtualDisplayConfig, target: DisplayActionHandler) -> NSMenuItem {
        let payload = MenuPayload(displayID: config.id, presetID: preset.id)
        let failedIDs = engine.failedPresetIDs(for: config.id)
        let hasError = engine.lastError(for: config.id) != nil || failedIDs.contains(preset.id)

        let logicalWidth = preset.width / 2
        let logicalHeight = preset.height / 2
        let baseTitle = "\(preset.name) (\(preset.width)×\(preset.height)@\(preset.refreshRate) / \(logicalWidth)×\(logicalHeight) HiDPI)"

        let item = NSMenuItem(
            title: baseTitle,
            action: #selector(DisplayActionHandler.presetSelected(_:)),
            keyEquivalent: ""
        )
        item.target = target
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
