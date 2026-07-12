import Foundation

public enum ConfigurationExportType: String, Codable {
    case full, display, preset
}

public struct ConfigurationExport: Codable {
    public let schemaVersion: Int
    public let exportType: ConfigurationExportType
    public let exportedAt: Date
    public let payload: ConfigurationExportPayload

    public init(schemaVersion: Int, exportType: ConfigurationExportType, exportedAt: Date, payload: ConfigurationExportPayload) {
        self.schemaVersion = schemaVersion
        self.exportType = exportType
        self.exportedAt = exportedAt
        self.payload = payload
    }
}

public struct ConfigurationExportPayload: Codable {
    public var displays: [ExportedDisplay]?
    public var display: ExportedDisplay?
    public var preset: ExportedPreset?

    public init(displays: [ExportedDisplay]? = nil, display: ExportedDisplay? = nil, preset: ExportedPreset? = nil) {
        self.displays = displays
        self.display = display
        self.preset = preset
    }
}

public struct ExportedDisplay: Codable {
    public var name: String
    public var presets: [ExportedPreset]
    public var activePresetIDs: [String]
    public var multiResolutionMode: Bool
    public var isEnabled: Bool

    public init(name: String, presets: [ExportedPreset], activePresetIDs: [String], multiResolutionMode: Bool, isEnabled: Bool) {
        self.name = name
        self.presets = presets
        self.activePresetIDs = activePresetIDs
        self.multiResolutionMode = multiResolutionMode
        self.isEnabled = isEnabled
    }
}

public struct ExportedPreset: Codable {
    public var id: String
    public var name: String
    public var width: Int
    public var height: Int
    public var refreshRate: Int

    public init(id: String, name: String, width: Int, height: Int, refreshRate: Int) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.refreshRate = refreshRate
    }
}

public enum ImportStrategy {
    case replace, merge
}

public struct ImportResult {
    public let configuration: AppConfiguration
    public let importedDisplayIDs: [String]
    public let importedPresetCount: Int
}

public enum ConfigurationExchangeError: LocalizedError {
    case invalidSchema(Int)
    case missingPayload
    case invalidExportType
    case noTargetDisplay
    case invalidData(String)
    case invalidPreset(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSchema(let version):
            return L10n.pick("不支持的导出 schema 版本：\(version)。", "Unsupported export schema version: \(version).")
        case .missingPayload:
            return L10n.pick("导出文件缺少有效内容。", "The export file contains no valid content.")
        case .invalidExportType:
            return L10n.pick("不支持的导出类型。", "Unsupported export type.")
        case .noTargetDisplay:
            return L10n.pick("未找到目标显示器，无法导入单个预设。", "Target display not found; cannot import a single preset.")
        case .invalidData(let message):
            return message
        case .invalidPreset(let message):
            return message
        }
    }
}

public enum ConfigurationExporter {
    public static func exportFull(_ config: AppConfiguration) -> ConfigurationExport {
        let displays = config.displays.map(ExportedDisplay.init)
        return ConfigurationExport(
            schemaVersion: 1,
            exportType: .full,
            exportedAt: Date(),
            payload: ConfigurationExportPayload(displays: displays)
        )
    }

    public static func exportDisplay(_ display: VirtualDisplayConfig) -> ConfigurationExport {
        ConfigurationExport(
            schemaVersion: 1,
            exportType: .display,
            exportedAt: Date(),
            payload: ConfigurationExportPayload(display: ExportedDisplay(display))
        )
    }

    public static func exportPreset(_ preset: DisplayPreset) -> ConfigurationExport {
        ConfigurationExport(
            schemaVersion: 1,
            exportType: .preset,
            exportedAt: Date(),
            payload: ConfigurationExportPayload(preset: ExportedPreset(preset))
        )
    }
}

public enum ConfigurationImporter {
    public static func importConfiguration(
        _ export: ConfigurationExport,
        into current: AppConfiguration,
        strategy: ImportStrategy,
        targetDisplayID: String? = nil
    ) throws -> ImportResult {
        guard export.schemaVersion == 1 else {
            throw ConfigurationExchangeError.invalidSchema(export.schemaVersion)
        }

        switch export.exportType {
        case .full:
            guard let displays = export.payload.displays, !displays.isEmpty else {
                throw ConfigurationExchangeError.missingPayload
            }
            return try importFull(displays: displays, into: current, strategy: strategy)
        case .display:
            guard let display = export.payload.display else {
                throw ConfigurationExchangeError.missingPayload
            }
            return try importDisplay(display: display, into: current, strategy: strategy)
        case .preset:
            guard let preset = export.payload.preset else {
                throw ConfigurationExchangeError.missingPayload
            }
            return try importPreset(preset: preset, into: current, strategy: strategy, targetDisplayID: targetDisplayID)
        }
    }

    private static func importFull(displays: [ExportedDisplay], into current: AppConfiguration, strategy: ImportStrategy) throws -> ImportResult {
        var importedConfigs: [VirtualDisplayConfig] = []
        var importedPresetCount = 0

        for exported in displays {
            let config = try makeDisplay(from: exported, existingDisplays: current.displays + importedConfigs)
            importedConfigs.append(config)
            importedPresetCount += config.presets.count
        }

        let result: AppConfiguration
        switch strategy {
        case .replace:
            result = AppConfiguration(
                version: current.version,
                displays: importedConfigs,
                selectedDisplayID: importedConfigs.first?.id
            )
        case .merge:
            var merged = current.displays
            for config in importedConfigs {
                merged.append(config)
            }
            let selected = current.displays.contains(where: { $0.id == current.selectedDisplayID })
                ? current.selectedDisplayID
                : merged.first?.id
            result = AppConfiguration(version: current.version, displays: merged, selectedDisplayID: selected)
        }

        return ImportResult(
            configuration: result,
            importedDisplayIDs: importedConfigs.map(\.id),
            importedPresetCount: importedPresetCount
        )
    }

    private static func importDisplay(display: ExportedDisplay, into current: AppConfiguration, strategy: ImportStrategy) throws -> ImportResult {
        let imported = try makeDisplay(from: display, existingDisplays: current.displays)
        var displays = current.displays

        switch strategy {
        case .replace:
            if let index = displays.firstIndex(where: { $0.name == imported.name }) {
                displays[index] = imported
            } else {
                displays.append(imported)
            }
        case .merge:
            displays.append(imported)
        }

        let selected = current.displays.contains(where: { $0.id == current.selectedDisplayID })
            ? current.selectedDisplayID
            : displays.first?.id
        let result = AppConfiguration(version: current.version, displays: displays, selectedDisplayID: selected)
        return ImportResult(
            configuration: result,
            importedDisplayIDs: [imported.id],
            importedPresetCount: imported.presets.count
        )
    }

    private static func importPreset(preset: ExportedPreset, into current: AppConfiguration, strategy: ImportStrategy, targetDisplayID: String?) throws -> ImportResult {
        let targetID = targetDisplayID ?? current.selectedDisplayID ?? current.displays.first?.id
        guard let targetID = targetID,
              let index = current.displays.firstIndex(where: { $0.id == targetID }) else {
            throw ConfigurationExchangeError.noTargetDisplay
        }

        try validate(preset: preset)

        var displays = current.displays
        var target = displays[index]

        let importedPreset = DisplayPreset(
            id: UUID().uuidString,
            name: uniqueName(preset.name, existingNames: target.presets.map(\.name), suffix: "_imported"),
            width: preset.width,
            height: preset.height,
            refreshRate: preset.refreshRate,
            vendorID: 0x0001,
            productID: 0x0001
        )

        if let existingIndex = target.presets.firstIndex(where: { $0.name == importedPreset.name && strategy == .replace }) {
            target.presets[existingIndex] = importedPreset
        } else {
            target.presets.append(importedPreset)
        }

        if target.multiResolutionMode {
            target.activePresetIDs.insert(importedPreset.id)
        } else {
            target.activePresetIDs = [importedPreset.id]
        }

        displays[index] = target
        let result = AppConfiguration(version: current.version, displays: displays, selectedDisplayID: current.selectedDisplayID)
        return ImportResult(
            configuration: result,
            importedDisplayIDs: [target.id],
            importedPresetCount: 1
        )
    }

    private static func makeDisplay(from exported: ExportedDisplay, existingDisplays: [VirtualDisplayConfig]) throws -> VirtualDisplayConfig {
        guard DisplayEngine.isValidDisplayName(exported.name) else {
            throw ConfigurationExchangeError.invalidData(L10n.pick("显示器名称「\(exported.name)」包含非法字符。", "Display name \"\(exported.name)\" contains invalid characters."))
        }

        let displayName = uniqueName(exported.name, existingNames: existingDisplays.map(\.name), suffix: "_imported")
        let serialNumber = DisplayEngine.nextSerialNumber(for: existingDisplays)

        var presetMap: [String: DisplayPreset] = [:]
        var presets: [DisplayPreset] = []
        for exportedPreset in exported.presets {
            try validate(preset: exportedPreset)
            let preset = DisplayPreset(
                id: UUID().uuidString,
                name: uniqueName(
                    exportedPreset.name,
                    existingNames: presets.map(\.name),
                    suffix: "_imported"
                ),
                width: exportedPreset.width,
                height: exportedPreset.height,
                refreshRate: exportedPreset.refreshRate,
                vendorID: 0x0001,
                productID: 0x0001
            )
            presetMap[exportedPreset.id] = preset
            presets.append(preset)
        }

        var activeIDs = exported.activePresetIDs.compactMap { presetMap[$0]?.id }
        if activeIDs.isEmpty, let first = presets.first {
            activeIDs = [first.id]
        }
        if !exported.multiResolutionMode, activeIDs.count > 1 {
            activeIDs = [activeIDs[0]]
        }

        return VirtualDisplayConfig(
            id: UUID().uuidString,
            name: displayName,
            presets: presets,
            activePresetIDs: Set(activeIDs),
            multiResolutionMode: exported.multiResolutionMode,
            serialNumber: serialNumber,
            vendorID: 0x0001,
            productID: serialNumber,
            isEnabled: exported.isEnabled
        )
    }

    private static func validate(preset: ExportedPreset) throws {
        do {
            try DisplayEngine.validatePreset(name: preset.name, width: preset.width, height: preset.height, refreshRate: preset.refreshRate)
        } catch let error as DisplayEngineError {
            throw ConfigurationExchangeError.invalidPreset(error.localizedDescription)
        }
    }

    private static func uniqueName(_ base: String, existingNames: [String], suffix: String) -> String {
        guard existingNames.contains(base) else { return base }
        let suffixed = "\(base)\(suffix)"
        guard existingNames.contains(suffixed) else { return suffixed }
        var counter = 1
        var candidate = "\(suffixed)_\(counter)"
        while existingNames.contains(candidate) {
            counter += 1
            candidate = "\(suffixed)_\(counter)"
        }
        return candidate
    }
}

extension ExportedDisplay {
    init(_ display: VirtualDisplayConfig) {
        let orderedPresetIDs = display.presets.map(\.id).filter { display.activePresetIDs.contains($0) }
        self.init(
            name: display.name,
            presets: display.presets.map(ExportedPreset.init),
            activePresetIDs: orderedPresetIDs,
            multiResolutionMode: display.multiResolutionMode,
            isEnabled: display.isEnabled
        )
    }
}

extension ExportedPreset {
    init(_ preset: DisplayPreset) {
        self.init(
            id: preset.id,
            name: preset.name,
            width: preset.width,
            height: preset.height,
            refreshRate: preset.refreshRate
        )
    }
}
