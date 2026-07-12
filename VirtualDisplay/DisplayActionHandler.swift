import Cocoa

protocol DisplayActionHandlerDelegate: AnyObject {
    func applyDisplay(config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset?)
}

@objc
final class DisplayActionHandler: NSObject {
    private let store: ConfigurationStore
    private let engine: DisplayEngine
    private let sheetController: DisplaySheetController
    private let launchAgentManager: LaunchAgentManager
    private let updateChecker: UpdateChecker

    weak var delegate: DisplayActionHandlerDelegate?

    init(store: ConfigurationStore, engine: DisplayEngine, sheetController: DisplaySheetController, launchAgentManager: LaunchAgentManager = .shared, updateChecker: UpdateChecker = .shared) {
        self.store = store
        self.engine = engine
        self.sheetController = sheetController
        self.launchAgentManager = launchAgentManager
        self.updateChecker = updateChecker
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
            title: L10n.pick("添加显示器", "Add Display"),
            description: L10n.pick("输入新显示器的名称，仅支持字母、数字和下划线。", "Enter a name for the new display. Only letters, digits, and underscores are allowed."),
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
            title: L10n.pick("重命名显示器", "Rename Display"),
            description: L10n.pick("输入新的显示器名称，仅支持字母、数字和下划线。", "Enter a new display name. Only letters, digits, and underscores are allowed."),
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

        sheetController.showConfirmation(title: L10n.pick("删除显示器", "Delete Display"), message: L10n.pick("确定要删除「\(display.name)」吗？", "Are you sure you want to delete \"\(display.name)\"?")) { [weak self] confirmed in
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

        sheetController.showConfirmation(title: L10n.pick("删除分辨率", "Delete Resolution"), message: L10n.pick("确定要删除「\(preset.name)」吗？", "Are you sure you want to delete \"\(preset.name)\"?")) { [weak self] confirmed in
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
            title: L10n.pick("恢复默认预设", "Restore Default Presets"),
            informativeText: "",
            message: L10n.pick("这将把当前显示器的所有分辨率预设恢复为内置默认值，并删除你添加的自定义预设。继续吗？", "This will restore all resolution presets of the current display to the built-in defaults and delete your custom presets. Continue?")
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

    @objc func checkForUpdatesFromMenu(_: NSMenuItem) {
        checkForUpdates()
    }

    @objc func showSponsorQR(_: NSMenuItem) {
        sheetController.showSponsorQR()
    }

    @objc func openFeedback(_: NSMenuItem) {
        openFeedbackURL(version: localVersionString())
    }

    @objc func openGitHubStar(_: NSMenuItem) {
        openGitHubStarURL()
    }

    @objc func exportDiagnostics(_: NSMenuItem) {
        let report = DiagnosticsReport.build(store: store, engine: engine, appVersion: localVersionString())
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "")
        sheetController.showSavePanel(defaultName: "VirtualDisplay-Diagnostics-\(stamp).txt", contentTypes: [.plainText]) { [weak self] url in
            guard let self, let url else { return }
            do {
                try report.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self.sheetController.showError(title: L10n.pick("导出失败", "Export Failed"), message: error.localizedDescription)
            }
        }
    }

    private func checkForUpdates() {
        updateChecker.checkForUpdates { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let info):
                if info.isNewerThanLocal {
                    let localVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
                    self.sheetController.showUpdateAvailable(localVersion: localVersion, remoteVersion: info.version, htmlURL: info.htmlURL)
                } else {
                    self.sheetController.showUpToDate(version: self.localVersionString())
                }
            case .failure:
                self.sheetController.showError(title: L10n.pick("检查更新失败", "Update Check Failed"), message: L10n.pick("无法获取最新版本信息，请确认网络连接。", "Could not fetch the latest version information. Please check your network connection."))
            }
        }
    }

    private func localVersionString() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private func openFeedbackURL(version: String) {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let body = L10n.pick(
            "版本：v\(version)\nmacOS：\(osVersion)\n\n请描述你遇到的问题或建议：",
            "Version: v\(version)\nmacOS: \(osVersion)\n\nDescribe your issue or suggestion:"
        )
        var components = URLComponents(string: "https://github.com/youngyunxing/VirtualDisplay/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "title", value: L10n.pick("[反馈] ", "[Feedback] ")),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    private func openGitHubStarURL() {
        guard let url = URL(string: "https://github.com/youngyunxing/VirtualDisplay") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let success: Bool
        if launchAgentManager.isEnabled {
            success = launchAgentManager.disable()
        } else {
            success = launchAgentManager.enable()
        }
        if !success {
            sheetController.showError(title: L10n.pick("开机自启设置失败", "Failed to Configure Launch at Login"), message: L10n.pick("无法写入或加载登录项配置，请确认 VirtualDisplay.app 在 /Applications 目录。", "Could not write or load the login item configuration. Please make sure VirtualDisplay.app is in the /Applications folder."))
        }
    }

    // MARK: - Import / Export

    @objc func importConfiguration(_ sender: NSMenuItem) {
        sheetController.showOpenPanel { [weak self] url in
            guard let self, let url else { return }
            do {
                let data = try Data(contentsOf: url)
                let alert = NSAlert()
                alert.messageText = L10n.pick("导入配置", "Import Configuration")
                alert.informativeText = L10n.pick("选择导入方式：替换会覆盖当前所有显示器，合并会追加并自动重命名冲突项。", "Choose how to import: Replace overwrites all current displays; Merge appends and automatically renames conflicting items.")
                alert.addButton(withTitle: L10n.pick("替换", "Replace"))
                alert.addButton(withTitle: L10n.pick("合并", "Merge"))
                alert.addButton(withTitle: L10n.pick("取消", "Cancel"))
                let response = alert.runModal()
                guard response == .alertFirstButtonReturn || response == .alertSecondButtonReturn else { return }
                let strategy: ImportStrategy = (response == .alertFirstButtonReturn) ? .replace : .merge

                switch self.store.importConfiguration(from: data, strategy: strategy) {
                case .success(let result):
                    for display in result.configuration.displays {
                        self.delegate?.applyDisplay(config: display, selecting: nil)
                    }
                case .failure(let error):
                    self.sheetController.showError(title: L10n.pick("导入失败", "Import Failed"), message: error.localizedDescription)
                }
            } catch {
                self.sheetController.showError(title: L10n.pick("无法读取文件", "Unable to Read File"), message: error.localizedDescription)
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
                self.sheetController.showError(title: L10n.pick("导出失败", "Export Failed"), message: error.localizedDescription)
            }
        }
    }

    @objc func exportDisplay(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }) else { return }
        sheetController.showSavePanel(defaultName: "\(display.name).json") { [weak self] url in
            guard let self, let url else { return }
            do {
                let data = try self.store.exportDisplay(id: display.id)
                try data.write(to: url, options: .atomic)
            } catch {
                self.sheetController.showError(title: L10n.pick("导出失败", "Export Failed"), message: error.localizedDescription)
            }
        }
    }

    @objc func exportPreset(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuPayload,
              let display = store.configuration.displays.first(where: { $0.id == payload.displayID }),
              let presetID = payload.presetID,
              let preset = display.presets.first(where: { $0.id == presetID }) else { return }
        sheetController.showSavePanel(defaultName: "\(display.name)_\(preset.name).json") { [weak self] url in
            guard let self, let url else { return }
            do {
                let data = try self.store.exportPreset(preset)
                try data.write(to: url, options: .atomic)
            } catch {
                self.sheetController.showError(title: L10n.pick("导出失败", "Export Failed"), message: error.localizedDescription)
            }
        }
    }
}
