import Foundation
import CoreGraphics

public enum DisplayEngineError: LocalizedError {
    case invalidPreset(String)
    case displayCreationFailed(String)
    case applySettingsFailed(String)
    case mirroringConfigurationFailed(String)
    case noSelectedPreset(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPreset(let message):
            return message
        case .displayCreationFailed(let displayName):
            return L10n.pick("无法创建虚拟显示器「\(displayName)」。", "Failed to create virtual display \"\(displayName)\".")
        case .applySettingsFailed(let displayName):
            return L10n.pick("无法将分辨率设置应用到「\(displayName)」。", "Failed to apply resolution settings to \"\(displayName)\".")
        case .mirroringConfigurationFailed(let displayName):
            return L10n.pick("无法将「\(displayName)」设置为扩展模式。", "Failed to set \"\(displayName)\" to extended mode.")
        case .noSelectedPreset(let displayName):
            return L10n.pick("显示器「\(displayName)」没有可用的分辨率预设。", "Display \"\(displayName)\" has no available resolution presets.")
        }
    }
}

public final class DisplayEngine {
    public static let shared = DisplayEngine()

    private var activeDisplays: [String: CGVirtualDisplay] = [:]
    private var displayMaxPixels: [String: (width: Int, height: Int)] = [:]
    private var appliedDisplayNames: [String: String] = [:]
    private var lastAppliedActivePresets: [String: [DisplayPreset]] = [:]

    // 记录最后一次 apply 失败状态，供菜单 UI 置灰/提示使用。
    private var lastDisplayErrors: [String: DisplayEngineError] = [:]
    private var lastFailedPresetIDs: [String: Set<String>] = [:]

    private init() {}

    @discardableResult
    public func apply(config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset? = nil) -> Result<Void, DisplayEngineError> {
        guard config.isEnabled else {
            clearErrors(for: config.id)
            return .success(())
        }

        guard !config.presets.isEmpty else {
            let error = DisplayEngineError.noSelectedPreset(config.name)
            recordError(error, for: config)
            return .failure(error)
        }

        var validIDs = config.activePresetIDs.filter { id in config.presets.contains(where: { $0.id == id }) }
        if validIDs.isEmpty {
            validIDs = [config.presets[0].id]
        }
        if !config.multiResolutionMode && validIDs.count > 1 {
            validIDs = [validIDs.first!]
        }

        let activePresets = config.presets.filter { validIDs.contains($0.id) }

        var orderedPresets = activePresets
        if let selected = selectedPreset,
           let selectedIndex = orderedPresets.firstIndex(where: { $0.id == selected.id }) {
            orderedPresets.swapAt(0, selectedIndex)
        }

        let requiredMaxWidth = config.presets.map(\.width).max() ?? config.presets[0].width
        let requiredMaxHeight = config.presets.map(\.height).max() ?? config.presets[0].height

        let existingMax = displayMaxPixels[config.id]
        let needsRecreate = activeDisplays[config.id] == nil
            || (existingMax?.width ?? 0) < requiredMaxWidth
            || (existingMax?.height ?? 0) < requiredMaxHeight
            || appliedDisplayNames[config.id] != config.name

        if !needsRecreate && orderedPresets == lastAppliedActivePresets[config.id] ?? [] {
            clearErrors(for: config.id)
            return .success(())
        }
        lastAppliedActivePresets[config.id] = orderedPresets

        if needsRecreate {
            activeDisplays.removeValue(forKey: config.id)

            let descriptor = CGVirtualDisplayDescriptor()
            descriptor.setDispatchQueue(DispatchQueue.main)
            descriptor.name = config.name
            descriptor.maxPixelsWide = UInt32(requiredMaxWidth)
            descriptor.maxPixelsHigh = UInt32(requiredMaxHeight)
            descriptor.vendorID = config.vendorID
            descriptor.productID = config.productID
            descriptor.serialNumber = config.serialNumber
            descriptor.serialNum = config.serialNumber

            let display = CGVirtualDisplay(descriptor: descriptor)
            guard display.displayID != 0 else {
                let error = DisplayEngineError.displayCreationFailed(config.name)
                recordError(error, for: config)
                return .failure(error)
            }
            activeDisplays[config.id] = display
            displayMaxPixels[config.id] = (requiredMaxWidth, requiredMaxHeight)
            appliedDisplayNames[config.id] = config.name

            let mirrorResult = disableMirroring(for: display.displayID, displayName: config.name)
            if case let .failure(error) = mirrorResult {
                recordError(error, for: config)
                return .failure(error)
            }
        }

        guard let display = activeDisplays[config.id] else {
            let error = DisplayEngineError.displayCreationFailed(config.name)
            recordError(error, for: config)
            return .failure(error)
        }

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.rotation = 0
        settings.modes = orderedPresets.map { preset in
            CGVirtualDisplayMode(
                width: UInt(preset.width / 2),
                height: UInt(preset.height / 2),
                refreshRate: CGFloat(preset.refreshRate)
            )
        }

        guard display.apply(settings) else {
            let error = DisplayEngineError.applySettingsFailed(config.name)
            recordError(error, for: config, failedPresets: orderedPresets)
            return .failure(error)
        }

        clearErrors(for: config.id)
        return .success(())
    }

    @discardableResult
    public func applyAll(enabledConfigs: [VirtualDisplayConfig]) -> [(displayID: String, error: DisplayEngineError)] {
        var errors: [(displayID: String, error: DisplayEngineError)] = []
        for config in enabledConfigs where config.isEnabled {
            if case let .failure(error) = apply(config: config) {
                errors.append((config.id, error))
            }
        }
        return errors
    }

    // MARK: - Error state

    public func lastError(for displayID: String) -> DisplayEngineError? {
        lastDisplayErrors[displayID]
    }

    public func failedPresetIDs(for displayID: String) -> Set<String> {
        lastFailedPresetIDs[displayID] ?? []
    }

    public func clearErrors(for displayID: String) {
        lastDisplayErrors.removeValue(forKey: displayID)
        lastFailedPresetIDs.removeValue(forKey: displayID)
    }

    private func recordError(_ error: DisplayEngineError, for config: VirtualDisplayConfig, failedPresets: [DisplayPreset] = []) {
        lastDisplayErrors[config.id] = error
        lastFailedPresetIDs[config.id] = Set(failedPresets.map(\.id))
    }

    public func remove(configID: String) {
        activeDisplays.removeValue(forKey: configID)
        displayMaxPixels.removeValue(forKey: configID)
        appliedDisplayNames.removeValue(forKey: configID)
        lastAppliedActivePresets.removeValue(forKey: configID)
        clearErrors(for: configID)
    }

    public var activeDisplayIDs: [String] { Array(activeDisplays.keys) }

    public func isOnline(_ config: VirtualDisplayConfig) -> Bool {
        guard let displayID = findDisplayID(for: config) else { return false }
        return isDisplayOnline(displayID)
    }

    public func findDisplayID(for config: VirtualDisplayConfig) -> CGDirectDisplayID? {
        if let display = activeDisplays[config.id] {
            return display.displayID
        }
        guard config.vendorID != 0 || config.productID != 0 || config.serialNumber != 0 else {
            return nil
        }

        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else { return nil }

        let count = Int(displayCount)
        var displays = [CGDirectDisplayID](repeating: 0, count: count)
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else { return nil }

        for displayID in displays where displayID != 0 {
            if CGDisplayVendorNumber(displayID) == config.vendorID,
               CGDisplayModelNumber(displayID) == config.productID,
               CGDisplaySerialNumber(displayID) == config.serialNumber {
                return displayID
            }
        }
        return nil
    }

    public func currentMode(for config: VirtualDisplayConfig) -> (logicalWidth: Int, logicalHeight: Int, refreshRate: Double)? {
        guard let displayID = findDisplayID(for: config),
              let mode = CGDisplayCopyDisplayMode(displayID) else {
            return nil
        }
        return (Int(mode.width), Int(mode.height), mode.refreshRate)
    }

    public static func matchCurrentPreset(
        presets: [DisplayPreset],
        mode: (logicalWidth: Int, logicalHeight: Int, refreshRate: Double)?
    ) -> DisplayPreset? {
        guard let mode else { return nil }
        let matched = presets.filter {
            $0.width / 2 == mode.logicalWidth && $0.height / 2 == mode.logicalHeight
        }
        guard !matched.isEmpty else { return nil }
        if mode.refreshRate > 0,
           let exact = matched.first(where: { Int(mode.refreshRate) == $0.refreshRate }) {
            return exact
        }
        return matched.first
    }

    public func currentPreset(for config: VirtualDisplayConfig) -> DisplayPreset? {
        Self.matchCurrentPreset(presets: config.presets, mode: currentMode(for: config))
    }

    private func isDisplayOnline(_ displayID: CGDirectDisplayID) -> Bool {
        guard displayID != 0 else { return false }
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else { return false }

        let count = Int(displayCount)
        var displays = [CGDirectDisplayID](repeating: 0, count: count)
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else { return false }

        return displays.contains(displayID)
    }

    private func disableMirroring(for displayID: CGDirectDisplayID, displayName: String) -> Result<Void, DisplayEngineError> {
        guard displayID != 0 else {
            return .failure(.mirroringConfigurationFailed(displayName))
        }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            return .failure(.mirroringConfigurationFailed(displayName))
        }
        CGConfigureDisplayMirrorOfDisplay(config, displayID, kCGNullDirectDisplay)
        let result = CGCompleteDisplayConfiguration(config, .forSession)
        if result != .success {
            return .failure(.mirroringConfigurationFailed(displayName))
        }
        return .success(())
    }

    // MARK: - Defaults

    public static func defaultDisplayConfig() -> VirtualDisplayConfig {
        let presets = defaultPresets()
        return VirtualDisplayConfig(
            id: UUID().uuidString,
            name: "VirtualDisplay",
            presets: presets,
            activePresetIDs: [presets[0].id],
            multiResolutionMode: false,
            serialNumber: 1,
            vendorID: 0x0001,
            productID: 0x0001
        )
    }

    public static func defaultPresets() -> [DisplayPreset] {
        return [
            DisplayPreset(
                id: "4k-uhd",
                name: "4K UHD",
                width: 3840,
                height: 2160,
                refreshRate: 60,
                vendorID: 0x0003,
                productID: 0x0001
            ),
            DisplayPreset(
                id: "1080p-fhd",
                name: "1080p FHD",
                width: 1920,
                height: 1080,
                refreshRate: 60,
                vendorID: 0x0004,
                productID: 0x0001
            ),
            DisplayPreset(
                id: "macbook-m1-13-native",
                name: L10n.pick("MacBook 13 寸原生", "MacBook 13\" Native"),
                width: 2560,
                height: 1600,
                refreshRate: 60,
                vendorID: 0x0002,
                productID: 0x0001
            ),
            DisplayPreset(
                id: "macbook-m1-13-scaled",
                name: L10n.pick("MacBook 13 寸缩放", "MacBook 13\" Scaled"),
                width: 2880,
                height: 1800,
                refreshRate: 60,
                vendorID: 0x0002,
                productID: 0x0002
            ),
            DisplayPreset(
                id: "oppo-pad-3",
                name: "OPPO Pad 3",
                width: 2800,
                height: 2000,
                refreshRate: 60,
                vendorID: 0x0001,
                productID: 0x0001
            ),
        ]
    }

    // MARK: - Validation helpers

    public static func isValidDisplayName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let range = NSRange(location: 0, length: name.utf16.count)
        let regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9_]+$")
        return regex?.firstMatch(in: name, options: [], range: range) != nil
    }

    public static func isDisplayNameUnique(_ name: String, in displays: [VirtualDisplayConfig], excluding displayID: String? = nil) -> Bool {
        !displays.contains(where: { $0.name == name && $0.id != displayID })
    }

    public static func nextSerialNumber(for displays: [VirtualDisplayConfig]) -> UInt32 {
        (displays.map(\.serialNumber).max() ?? 0) + 1
    }

    public static func validatePreset(name: String, width: Int, height: Int, refreshRate: Int) throws {
        guard !name.isEmpty else {
            throw DisplayEngineError.invalidPreset(L10n.pick("名称不能为空。", "Name cannot be empty."))
        }
        guard width > 0, height > 0, refreshRate > 0 else {
            throw DisplayEngineError.invalidPreset(L10n.pick("宽度、高度、刷新率必须为正整数。", "Width, height, and refresh rate must be positive integers."))
        }
        guard width % 2 == 0, height % 2 == 0 else {
            throw DisplayEngineError.invalidPreset(L10n.pick("HiDPI 模式下宽度和高度必须为偶数。", "Width and height must be even numbers in HiDPI mode."))
        }
    }
}
