import Cocoa
import CoreGraphics
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    private let logger = Logger(subsystem: "com.youngyunxing.VirtualDisplay", category: "WakeRecovery")
    private var wakeRecoveryWorkItem: DispatchWorkItem?

    private let store = ConfigurationStore.shared
    private let engine = DisplayEngine.shared
    private lazy var sheetController = DisplaySheetController(store: store)
    private lazy var menuBuilder = MenuBuilder(store: store, engine: engine)
    private lazy var actionHandler: DisplayActionHandler = {
        let handler = DisplayActionHandler(store: store, engine: engine, sheetController: sheetController)
        handler.delegate = self
        return handler
    }()

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

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.store.load()

            if !UserDefaults.standard.bool(forKey: "hasConfiguredLaunchAtLogin") {
                _ = LaunchAgentManager.shared.enable()
                UserDefaults.standard.set(true, forKey: "hasConfiguredLaunchAtLogin")
            }

            self.applyChanges(affecting: nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return false
    }

    @objc private func statusBarButtonClicked(_: Any?) {
        statusItem.popUpMenu(menuBuilder.buildMenu(target: actionHandler))
    }

    @objc private func configurationDidChangeExternally(_ notification: Notification) {
        if let senderPID = notification.userInfo?["senderPID"] as? Int,
           senderPID == ProcessInfo.processInfo.processIdentifier {
            return
        }

        let affectedIDs = notification.userInfo?[ConfigurationStore.affectedDisplayIDsKey] as? [String]

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.store.load()
            self.applyChanges(affecting: affectedIDs)
        }
    }

    private func applyChanges(affecting affectedDisplayIDs: [String]?) {
        let configs = store.configuration.displays
        let enabledIDs = Set(configs.filter(\.isEnabled).map(\.id))

        // 移除已关闭/已被删除的显示器
        for id in engine.activeDisplayIDs where !enabledIDs.contains(id) {
            engine.remove(configID: id)
        }

        let idsToApply: [String]
        if let affected = affectedDisplayIDs {
            idsToApply = affected.filter { enabledIDs.contains($0) }
        } else {
            idsToApply = Array(enabledIDs)
        }

        for id in idsToApply {
            if let config = configs.first(where: { $0.id == id }) {
                apply(config: config)
            }
        }
    }

    private func apply(config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset? = nil) {
        _ = engine.apply(config: config, selecting: selectedPreset)
    }

    // MARK: - 睡眠唤醒恢复

    /// 系统睡眠后 WindowServer 会拆掉所有 CGVirtualDisplay，唤醒后引擎里持有的旧对象已失效。
    /// 这里延迟 0.8s（等 WindowServer 就绪）后清掉旧对象强制重建，失败再重试一次。
    @objc private func systemDidWake(_: Notification) {
        scheduleWakeRecovery(attempt: 1)
    }

    private func scheduleWakeRecovery(attempt: Int) {
        wakeRecoveryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.store.load()
            let enabledConfigs = self.store.configuration.displays.filter(\.isEnabled)
            guard !enabledConfigs.isEmpty else { return }

            self.logger.info("系统唤醒，开始恢复 \(enabledConfigs.count) 个虚拟显示器（第 \(attempt) 次尝试）")

            // 清掉睡眠前遗留的失效对象，确保走完整重建路径
            for config in enabledConfigs {
                self.engine.remove(configID: config.id)
            }
            self.applyChanges(affecting: nil)

            let failed = enabledConfigs.filter { self.engine.lastError(for: $0.id) != nil }
            if !failed.isEmpty {
                if attempt < 2 {
                    self.logger.warning("\(failed.count) 个显示器恢复失败，1s 后重试")
                    self.scheduleWakeRecovery(attempt: attempt + 1)
                } else {
                    self.logger.error("\(failed.count) 个显示器恢复失败，已放弃重试：\(failed.map(\.name).joined(separator: ", "))")
                }
            } else {
                self.logger.info("虚拟显示器已全部恢复")
            }
        }
        wakeRecoveryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
}

extension AppDelegate: DisplayActionHandlerDelegate {
    func applyDisplay(config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset?) {
        apply(config: config, selecting: selectedPreset)
    }
}
