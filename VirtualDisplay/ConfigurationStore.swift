import Foundation

public final class ConfigurationStore {
    public static let shared = ConfigurationStore()

    public static let suiteName = "com.youngyunxing.VirtualDisplay"
    public static let configurationKey = "appConfigurationV2"
    public static let configChangedNotificationName = "com.youngyunxing.VirtualDisplay.configChanged"
    public static let affectedDisplayIDsKey = "affectedDisplayIDs"

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var _configuration: AppConfiguration

    public var configuration: AppConfiguration {
        get { lock.withLock { _configuration } }
        set {
            lock.withLock {
                _configuration = newValue
                _saveUnlocked()
                _postChangeNotificationUnlocked(affectedDisplayIDs: nil)
            }
        }
    }

    public init(defaults: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard) {
        self.defaults = defaults
        _configuration = AppConfiguration(version: 2, displays: [], selectedDisplayID: nil)
    }

    @discardableResult
    public func load() -> AppConfiguration {
        lock.withLock {
            _loadUnlocked()
            return _configuration
        }
    }

    public func save() {
        lock.withLock {
            _saveUnlocked()
        }
    }

    public func mutate(affecting displayIDs: [String]? = nil, _ change: (inout AppConfiguration) -> Void) {
        lock.withLock {
            _loadUnlocked()
            var config = _configuration
            change(&config)
            _configuration = config
            _saveUnlocked()
            _postChangeNotificationUnlocked(affectedDisplayIDs: displayIDs)
        }
    }

    public func postChangeNotification(affectedDisplayIDs: [String]? = nil) {
        lock.withLock {
            _postChangeNotificationUnlocked(affectedDisplayIDs: affectedDisplayIDs)
        }
    }

    // MARK: - Unlocked internals

    private func _loadUnlocked() {
        if let data = defaults.data(forKey: Self.configurationKey),
           let config = try? JSONDecoder().decode(AppConfiguration.self, from: data),
           !config.displays.isEmpty {
            _configuration = config
        } else {
            let defaultDisplay = DisplayEngine.defaultDisplayConfig()
            _configuration = AppConfiguration(
                version: 2,
                displays: [defaultDisplay],
                selectedDisplayID: defaultDisplay.id
            )
        }

        if _configuration.selectedDisplayID == nil ||
            !_configuration.displays.contains(where: { $0.id == _configuration.selectedDisplayID }) {
            _configuration.selectedDisplayID = _configuration.displays.first?.id
        }

        for index in _configuration.displays.indices {
            var validIDs = _configuration.displays[index].activePresetIDs.filter { id in
                _configuration.displays[index].presets.contains(where: { $0.id == id })
            }
            if validIDs.isEmpty, let firstPreset = _configuration.displays[index].presets.first {
                validIDs = [firstPreset.id]
            }
            if !_configuration.displays[index].multiResolutionMode, validIDs.count > 1 {
                validIDs = [validIDs.first!]
            }
            _configuration.displays[index].activePresetIDs = Set(validIDs)
        }
    }

    private func _saveUnlocked() {
        if let data = try? JSONEncoder().encode(_configuration) {
            defaults.set(data, forKey: Self.configurationKey)
        }
    }

    private func _postChangeNotificationUnlocked(affectedDisplayIDs: [String]?) {
        var userInfo: [String: Any] = [
            "version": _configuration.version,
            "senderPID": ProcessInfo.processInfo.processIdentifier
        ]
        if let ids = affectedDisplayIDs {
            userInfo[Self.affectedDisplayIDsKey] = ids
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(Self.configChangedNotificationName),
            object: Self.suiteName,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }
}

private extension NSLocking {
    func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}
