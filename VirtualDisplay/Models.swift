import Foundation

public struct DisplayPreset: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let width: Int
    public let height: Int
    public let refreshRate: Int
    public let vendorID: UInt32
    public let productID: UInt32

    public init(id: String, name: String, width: Int, height: Int, refreshRate: Int, vendorID: UInt32, productID: UInt32) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.refreshRate = refreshRate
        self.vendorID = vendorID
        self.productID = productID
    }
}

public struct VirtualDisplayConfig: Codable, Identifiable {
    public let id: String
    public var name: String
    public var presets: [DisplayPreset]
    public var activePresetIDs: Set<String>
    public var multiResolutionMode: Bool
    public var serialNumber: UInt32
    public var vendorID: UInt32
    public var productID: UInt32
    public var isEnabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case id, name, presets, activePresetIDs, multiResolutionMode
        case serialNumber, vendorID, productID, isEnabled
    }

    public init(id: String,
                name: String,
                presets: [DisplayPreset],
                activePresetIDs: Set<String>,
                multiResolutionMode: Bool,
                serialNumber: UInt32,
                vendorID: UInt32,
                productID: UInt32,
                isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.presets = presets
        self.activePresetIDs = activePresetIDs
        self.multiResolutionMode = multiResolutionMode
        self.serialNumber = serialNumber
        self.vendorID = vendorID
        self.productID = productID
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        presets = try container.decode([DisplayPreset].self, forKey: .presets)
        activePresetIDs = try container.decode(Set<String>.self, forKey: .activePresetIDs)
        multiResolutionMode = try container.decode(Bool.self, forKey: .multiResolutionMode)
        serialNumber = try container.decode(UInt32.self, forKey: .serialNumber)
        vendorID = try container.decode(UInt32.self, forKey: .vendorID)
        productID = try container.decode(UInt32.self, forKey: .productID)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

public struct AppConfiguration: Codable {
    public var version: Int
    public var displays: [VirtualDisplayConfig]
    public var selectedDisplayID: String?

    public init(version: Int, displays: [VirtualDisplayConfig], selectedDisplayID: String?) {
        self.version = version
        self.displays = displays
        self.selectedDisplayID = selectedDisplayID
    }
}

public final class MenuPayload: NSObject {
    public let displayID: String
    public let presetID: String?

    public init(displayID: String, presetID: String? = nil) {
        self.displayID = displayID
        self.presetID = presetID
    }
}
