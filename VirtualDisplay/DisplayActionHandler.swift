import Cocoa

protocol DisplayActionHandlerDelegate: AnyObject {
    func applyDisplay(config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset?)
}

@objc
final class DisplayActionHandler: NSObject {
    private let store: ConfigurationStore
    private let engine: DisplayEngine
    private let sheetController: DisplaySheetController

    weak var delegate: DisplayActionHandlerDelegate?

    init(store: ConfigurationStore, engine: DisplayEngine, sheetController: DisplaySheetController) {
        self.store = store
        self.engine = engine
        self.sheetController = sheetController
        super.init()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Display management

    @objc func addDisplay(_: NSMenuItem) {
        let nextSerial = DisplayEngine.nextSerialNumber(for: store.configuration.displays)
        let defaultName = "VirtualDisplay_\(nextSerial)"

        sheetController.showDisplayNameEditor(
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

            self.store.mutate(affecting: [newDisplay.id]) { config in
                config.displays.append(newDisplay)
                config.selectedDisplayID = newDisplay.id
            }
            self.self.delegate?.applyDisplay(config: newDisplay, selecting: newDisplay.presets[0])
        }
    }

    @objc func renameDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }

        sheetController.showDisplayNameEditor(
            title: "重命名显示器",
            description: "输入新的显示器名称，仅支持字母、数字和下划线。",
            defaultName: display.name,
            excludingDisplayID: payload.displayID
        ) { [weak self] name in
            guard let self = self, let name = name else { return }

            self.store.mutate(affecting: [payload.displayID]) { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                config.displays[idx].name = name
            }
            if let updated = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                self.self.delegate?.applyDisplay(config: updated, selecting: nil)
            }
        }
    }

    @objc func deleteDisplay(_ sender: NSMenuItem) {
        guard store.configuration.displays.count > 1,
              let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }

        sheetController.showConfirmation(title: "删除显示器", message: "确定要删除「\(display.name)」吗？") { [weak self] confirmed in
            guard let self = self, confirmed else { return }
            self.engine.remove(configID: display.id)
            self.store.mutate(affecting: [payload.displayID]) { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                config.displays.remove(at: idx)
                if config.selectedDisplayID == display.id {
                    let newIndex = min(idx, max(config.displays.count - 1, 0))
                    config.selectedDisplayID = config.displays[newIndex].id
                }
            }
        }
    }

    @objc func refreshDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let config = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }

        if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
            self.delegate?.applyDisplay(config: updated, selecting: nil)
        }
    }

    @objc func toggleDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let config = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }
        let isOnline = engine.isOnline(config)

        if isOnline {
            engine.remove(configID: config.id)
            store.mutate(affecting: [payload.displayID]) { configuration in
                guard let idx = configuration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                configuration.displays[idx].isEnabled = false
            }
        } else {
            store.mutate(affecting: [payload.displayID]) { configuration in
                guard let idx = configuration.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                configuration.displays[idx].isEnabled = true
            }
            if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                self.delegate?.applyDisplay(config: updated, selecting: nil)
            }
        }
    }

    // MARK: - Preset actions

    @objc func presetSelected(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }

        store.mutate(affecting: [payload.displayID]) { config in
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
            self.delegate?.applyDisplay(config: updated, selecting: preset)
        }
    }

    @objc func addPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload else { return }

        sheetController.showPresetEditor(displayID: payload.displayID, preset: nil) { [weak self] newPreset in
            guard let self = self, let newPreset = newPreset else { return }
            self.store.mutate(affecting: [payload.displayID]) { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                config.displays[idx].presets.append(newPreset)
                if !config.displays[idx].multiResolutionMode {
                    config.displays[idx].activePresetIDs = [newPreset.id]
                } else {
                    config.displays[idx].activePresetIDs.insert(newPreset.id)
                }
            }
            if let updated = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                self.self.delegate?.applyDisplay(config: updated, selecting: newPreset)
            }
        }
    }

    @objc func editPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }
        sheetController.showPresetEditor(displayID: payload.displayID, preset: preset) { [weak self] updatedPreset in
            guard let self = self, let updated = updatedPreset else { return }
            self.store.mutate(affecting: [payload.displayID]) { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }),
                      let pIdx = config.displays[idx].presets.firstIndex(where: { $0.id == presetID }) else { return }
                config.displays[idx].presets[pIdx] = updated
            }
            if let updatedConfig = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                if updatedConfig.activePresetIDs.contains(updated.id) {
                    self.self.delegate?.applyDisplay(config: updatedConfig, selecting: updated)
                } else {
                    self.self.delegate?.applyDisplay(config: updatedConfig, selecting: nil)
                }
            }
        }
    }

    @objc func deletePreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }

        sheetController.showConfirmation(title: "删除分辨率", message: "确定要删除「\(preset.name)」吗？") { [weak self] confirmed in
            guard let self = self, confirmed else { return }

            self.store.mutate(affecting: [payload.displayID]) { config in
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

            if let updated = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                self.self.delegate?.applyDisplay(config: updated, selecting: nil)
            }
        }
    }

    @objc func restoreDefaultPresets(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload else { return }

        sheetController.showRestorableAlert(
            title: "恢复默认预设",
            informativeText: "",
            message: "这将把当前显示器的所有分辨率预设恢复为内置默认值，并删除你添加的自定义预设。继续吗？"
        ) { [weak self] confirmed in
            guard let self = self, confirmed else { return }

            self.store.mutate(affecting: [payload.displayID]) { config in
                guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
                let presets = DisplayEngine.defaultPresets()
                guard !presets.isEmpty else { return }
                config.displays[idx].presets = presets
                config.displays[idx].activePresetIDs = [presets[0].id]
            }

            if let updated = self.store.configuration.displays.first(where: { $0.id == payload.displayID }) {
                self.self.delegate?.applyDisplay(config: updated, selecting: nil)
            }
        }
    }

    @objc func toggleMultiResolutionMode(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload else { return }

        store.mutate(affecting: [payload.displayID]) { config in
            guard let idx = config.displays.firstIndex(where: { $0.id == payload.displayID }) else { return }
            config.displays[idx].multiResolutionMode.toggle()

            if !config.displays[idx].multiResolutionMode && config.displays[idx].activePresetIDs.count > 1 {
                if let firstActiveID = config.displays[idx].presets.first(where: { config.displays[idx].activePresetIDs.contains($0.id) })?.id {
                    config.displays[idx].activePresetIDs = [firstActiveID]
                }
            }
        }

        if let updated = store.configuration.displays.first(where: { $0.id == payload.displayID }) {
            self.delegate?.applyDisplay(config: updated, selecting: nil)
        }
    }

    // MARK: - Import / Export / Share

    @objc func importConfiguration(_ sender: NSMenuItem) {
        sheetController.showOpenPanel { [weak self] url in
            guard let self, let url else { return }
            do {
                let data = try Data(contentsOf: url)
                let alert = NSAlert()
                alert.messageText = "导入配置"
                alert.informativeText = "选择导入方式：替换会覆盖当前所有显示器，合并会追加并自动重命名冲突项。"
                alert.addButton(withTitle: "替换")
                alert.addButton(withTitle: "合并")
                alert.addButton(withTitle: "取消")
                let response = alert.runModal()
                guard response == .alertFirstButtonReturn || response == .alertSecondButtonReturn else { return }
                let strategy: ImportStrategy = (response == .alertFirstButtonReturn) ? .replace : .merge

                switch self.store.importConfiguration(from: data, strategy: strategy) {
                case .success(let result):
                    for display in result.configuration.displays {
                        self.delegate?.applyDisplay(config: display, selecting: nil)
                    }
                case .failure(let error):
                    self.sheetController.showError(title: "导入失败", message: error.localizedDescription ?? "未知错误")
                }
            } catch {
                self.sheetController.showError(title: "无法读取文件", message: error.localizedDescription)
            }
        }
    }

    @objc func exportConfiguration(_ sender: NSMenuItem) {
        sheetController.showSavePanel(defaultName: "VirtualDisplay.json") { [weak self] url in
            guard let self, let url else { return }
            do {
                let data = try self.store.exportFull()
                try data.write(to: url, options: .atomic)
            } catch {
                self.sheetController.showError(title: "导出失败", message: error.localizedDescription)
            }
        }
    }

    @objc func shareCurrentPreset(_ sender: NSMenuItem) {
        guard let displayID = store.configuration.selectedDisplayID,
              let display = store.configuration.displays.first(where: { $0.id == displayID }),
              let preset = display.presets.first(where: { display.activePresetIDs.contains($0.id) }) else {
            sheetController.showError(title: "无法分享", message: "当前没有选中的预设。")
            return
        }
        do {
            let data = try store.exportPreset(preset)
            shareExport(data, fileName: "\(display.name)_\(preset.name).json")
        } catch {
            sheetController.showError(title: "导出失败", message: error.localizedDescription)
        }
    }

    @objc func shareDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }
        do {
            let data = try store.exportDisplay(id: display.id)
            shareExport(data, fileName: "\(display.name).json")
        } catch {
            sheetController.showError(title: "导出失败", message: error.localizedDescription)
        }
    }

    @objc func sharePreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }
        do {
            let data = try store.exportPreset(preset)
            shareExport(data, fileName: "\(display.name)_\(preset.name).json")
        } catch {
            sheetController.showError(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func shareExport(_ data: Data, fileName: String) {
        guard let json = String(data: data, encoding: .utf8) else {
            sheetController.showError(title: "分享失败", message: "无法编码 JSON。")
            return
        }
        sheetController.copyStringToPasteboard(json)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL, options: .atomic)
            sheetController.showSharingServicePicker(items: [tempURL], sourceView: nil)
        } catch {
            sheetController.showError(title: "分享失败", message: error.localizedDescription)
        }
    }
}
