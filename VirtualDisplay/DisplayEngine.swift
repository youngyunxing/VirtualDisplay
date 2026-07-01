import Foundation
import CoreGraphics

public enum DisplayEngineError: LocalizedError {
    case invalidPreset(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPreset(let message):
            return message
        }
    }
}

public final class DisplayEngine {
    public static let shared = DisplayEngine()

    private var activeDisplays: [String: CGVirtualDisplay] = [:]
    private var displayMaxPixels: [String: (width: Int, height: Int)] = [:]
    private var appliedDisplayNames: [String: String] = [:]
    private var lastOrderedPresetIDs: [String: [String]] = [:]

    private init() {}

    public func apply(config: VirtualDisplayConfig, selecting selectedPreset: DisplayPreset? = nil) {
        guard config.isEnabled else { return }

        guard !config.presets.isEmpty else {
            NSLog("VirtualDisplay: display %@ has no presets, skipping apply", config.name)
            return
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

        let orderedIDs = orderedPresets.map(\.id)

        let requiredMaxWidth = config.presets.map(\.width).max() ?? config.presets[0].width
        let requiredMaxHeight = config.presets.map(\.height).max() ?? config.presets[0].height

        let existingMax = displayMaxPixels[config.id]
        let needsRecreate = activeDisplays[config.id] == nil
            || (existingMax?.width ?? 0) < requiredMaxWidth
            || (existingMax?.height ?? 0) < requiredMaxHeight
            || appliedDisplayNames[config.id] != config.name

        if !needsRecreate && orderedIDs == lastOrderedPresetIDs[config.id] {
            return
        }
        lastOrderedPresetIDs[config.id] = orderedIDs

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
            activeDisplays[config.id] = display
            displayMaxPixels[config.id] = (requiredMaxWidth, requiredMaxHeight)
            appliedDisplayNames[config.id] = config.name
            disableMirroring(for: display.displayID)
        }

        guard let display = activeDisplays[config.id] else { return }

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

        if !display.apply(settings) {
            NSLog("VirtualDisplay: apply settings failed for display %@", config.name)
        }
    }

    public func applyAll(enabledConfigs: [VirtualDisplayConfig]) {
        for config in enabledConfigs where config.isEnabled {
            apply(config: config)
        }
    }

    public func remove(configID: String) {
        activeDisplays.removeValue(forKey: configID)
        displayMaxPixels.removeValue(forKey: configID)
        appliedDisplayNames.removeValue(forKey: configID)
        lastOrderedPresetIDs.removeValue(forKey: configID)
    }

    public var activeDisplayIDs: [String] { Array(activeDisplays.keys) }

    public func isOnline(_ config: VirtualDisplayConfig) -> Bool {
        if let display = activeDisplays[config.id] {
            return isDisplayOnline(display.displayID)
        }
        return isOnlineByAttributes(config)
    }

    private func isOnlineByAttributes(_ config: VirtualDisplayConfig) -> Bool {
        guard config.vendorID != 0 || config.productID != 0 || config.serialNumber != 0 else {
            return false
        }

        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else { return false }

        let count = Int(displayCount)
        var displays = [CGDirectDisplayID](repeating: 0, count: count)
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else { return false }

        for displayID in displays where displayID != 0 {
            if CGDisplayVendorNumber(displayID) == config.vendorID,
               CGDisplayModelNumber(displayID) == config.productID,
               CGDisplaySerialNumber(displayID) == config.serialNumber {
                return true
            }
        }
        return false
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

    private func disableMirroring(for displayID: CGDirectDisplayID) {
        guard displayID != 0 else { return }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            NSLog("VirtualDisplay: CGBeginDisplayConfiguration failed")
            return
        }
        CGConfigureDisplayMirrorOfDisplay(config, displayID, kCGNullDirectDisplay)
        let result = CGCompleteDisplayConfiguration(config, .forSession)
        if result != .success {
            NSLog("VirtualDisplay: CGCompleteDisplayConfiguration failed: %d", result.rawValue)
        }
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
                name: "4K UHD 3840×2160（1920×1080 HiDPI）",
                width: 3840,
                height: 2160,
                refreshRate: 60,
                vendorID: 0x0003,
                productID: 0x0001
            ),
            DisplayPreset(
                id: "1080p-fhd",
                name: "1080p FHD 1920×1080（960×540 HiDPI）",
                width: 1920,
                height: 1080,
                refreshRate: 60,
                vendorID: 0x0004,
                productID: 0x0001
            ),
            DisplayPreset(
                id: "macbook-m1-13-native",
                name: "MacBook 经典 13 寸原生 2560×1600（1280×800 HiDPI）",
                width: 2560,
                height: 1600,
                refreshRate: 60,
                vendorID: 0x0002,
                productID: 0x0001
            ),
            DisplayPreset(
                id: "macbook-m1-13-scaled",
                name: "MacBook 经典 13 寸缩放 2880×1800（1440×900 HiDPI）",
                width: 2880,
                height: 1800,
                refreshRate: 60,
                vendorID: 0x0002,
                productID: 0x0002
            ),
            DisplayPreset(
                id: "oppo-pad-3",
                name: "OPPO Pad 3 2800×2000（1400×1000 HiDPI）",
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
            throw DisplayEngineError.invalidPreset("名称不能为空。")
        }
        guard width > 0, height > 0, refreshRate > 0 else {
            throw DisplayEngineError.invalidPreset("宽度、高度、刷新率必须为正整数。")
        }
        guard width % 2 == 0, height % 2 == 0 else {
            throw DisplayEngineError.invalidPreset("HiDPI 模式下宽度和高度必须为偶数。")
        }
    }
}
