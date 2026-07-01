import Foundation

public final class ConfigurationStore {
    public static let shared = ConfigurationStore()

    public static let suiteName = "com.youngyunxing.VirtualDisplay"
    public static let configurationKey = "appConfigurationV2"
    public static let configChangedNotificationName = "com.youngyunxing.VirtualDisplay.configChanged"

    private let defaults: UserDefaults
    private var _configuration: AppConfiguration

    public var configuration: AppConfiguration {
        get { _configuration }
        set {
            _configuration = newValue
            save()
            postChangeNotification()
        }
    }

    public init(defaults: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard) {
        self.defaults = defaults
        _configuration = AppConfiguration(version: 2, displays: [], selectedDisplayID: nil)
    }

    @discardableResult
    public func load() -> AppConfiguration {
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

        return _configuration
    }

    public func save() {
        if let data = try? JSONEncoder().encode(_configuration) {
            defaults.set(data, forKey: Self.configurationKey)
        }
    }

    public func mutate(_ change: (inout AppConfiguration) -> Void) {
        load()
        var config = _configuration
        change(&config)
        configuration = config
    }

    public func postChangeNotification() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(Self.configChangedNotificationName),
            object: Self.suiteName,
            userInfo: [
                "version": _configuration.version,
                "senderPID": ProcessInfo.processInfo.processIdentifier
            ],
            deliverImmediately: true
        )
    }
}
