import Cocoa
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

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

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.store.load()
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
}

extension AppDelegate: DisplayActionHandlerDelegate {
    func applyDisplay(config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset?) {
        apply(config: config, selecting: selectedPreset)
    }
}
