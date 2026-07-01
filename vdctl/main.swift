import Foundation
import AppKit

struct CLIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct DisplayListItem: Codable {
    let id: String
    let name: String
    let enabled: Bool
    let multiResolutionMode: Bool
}

struct PresetListItem: Codable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let refreshRate: Int
    let active: Bool
}

struct DisplayStatus: Codable {
    let id: String
    let name: String
    let enabled: Bool
    let online: Bool
    let multiResolutionMode: Bool
    let activePresetIDs: [String]
}

struct StatusOutput: Codable {
    let appRunning: Bool
    let version: Int
    let selectedDisplayID: String?
    let displays: [DisplayStatus]
}

struct SuccessOutput: Codable {
    let success: Bool
}

struct PresetSuccessOutput: Codable {
    let success: Bool
    let displayID: String
    let activePresetIDs: [String]
}

private let appBundleID = "com.youngyunxing.VirtualDisplay"
private let appBundlePath = "/Applications/VirtualDisplay.app"

private func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(value),
       let string = String(data: data, encoding: .utf8) {
        print(string)
    }
}

private func fail(_ message: String) -> Never {
    struct ErrorOutput: Codable {
        let error: String
    }
    let output = ErrorOutput(error: message)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if let data = try? encoder.encode(output),
       let string = String(data: data, encoding: .utf8) {
        fputs(string + "\n", stderr)
    }
    exit(1)
}

private func appURL() -> URL {
    let bundleURL = Bundle.main.bundleURL
    if bundleURL.pathExtension == "app" {
        return bundleURL
    }
    return URL(fileURLWithPath: appBundlePath)
}

private func isAppRunning() -> Bool {
    NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == appBundleID }
}

private func ensureAppRunning(timeout: TimeInterval = 10) throws {
    guard !isAppRunning() else { return }

    let url = appURL()
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw CLIError(message: "VirtualDisplay.app not found at \(url.path)")
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-g", url.path]
    try process.run()
    process.waitUntilExit()

    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if isAppRunning() { return }
        Thread.sleep(forTimeInterval: 0.2)
    }

    throw CLIError(message: "VirtualDisplay.app did not become running within \(Int(timeout))s")
}

private func findDisplay(in config: AppConfiguration, identifier: String) -> (index: Int, display: VirtualDisplayConfig)? {
    if let index = config.displays.firstIndex(where: { $0.id == identifier }) {
        return (index, config.displays[index])
    }
    if let index = config.displays.firstIndex(where: { $0.name == identifier }) {
        return (index, config.displays[index])
    }
    return nil
}

private func findPreset(in display: VirtualDisplayConfig, identifier: String) -> (index: Int, preset: DisplayPreset)? {
    if let index = display.presets.firstIndex(where: { $0.id == identifier }) {
        return (index, display.presets[index])
    }
    if let index = display.presets.firstIndex(where: { $0.name == identifier }) {
        return (index, display.presets[index])
    }
    return nil
}

// MARK: - Commands

private func handleList(args: [String], store: ConfigurationStore) throws {
    guard let subcommand = args.first else {
        fail("Usage: vdctl list displays | vdctl list presets <display>")
    }

    switch subcommand {
    case "displays":
        let items = store.configuration.displays.map {
            DisplayListItem(
                id: $0.id,
                name: $0.name,
                enabled: $0.isEnabled,
                multiResolutionMode: $0.multiResolutionMode
            )
        }
        printJSON(items)

    case "presets":
        guard args.count > 1 else { fail("Missing display identifier") }
        guard let display = findDisplay(in: store.configuration, identifier: args[1])?.display else {
            fail("Display not found: \(args[1])")
        }
        let items = display.presets.map {
            PresetListItem(
                id: $0.id,
                name: $0.name,
                width: $0.width,
                height: $0.height,
                refreshRate: $0.refreshRate,
                active: display.activePresetIDs.contains($0.id)
            )
        }
        printJSON(items)

    default:
        fail("Unknown list target: \(subcommand)")
    }
}

private func handleAdd(args: [String], store: ConfigurationStore) throws {
    guard let subcommand = args.first else {
        fail("Usage: vdctl add display <name> | vdctl add preset ...")
    }

    switch subcommand {
    case "display":
        guard args.count > 1 else { fail("Usage: vdctl add display <name>") }
        let name = args[1]
        guard DisplayEngine.isValidDisplayName(name) else { fail("Invalid display name: \(name)") }
        guard DisplayEngine.isDisplayNameUnique(name, in: store.configuration.displays) else {
            fail("Display name already exists: \(name)")
        }

        let presets = DisplayEngine.defaultPresets()
        let serial = DisplayEngine.nextSerialNumber(for: store.configuration.displays)
        let display = VirtualDisplayConfig(
            id: UUID().uuidString,
            name: name,
            presets: presets,
            activePresetIDs: [presets[0].id],
            multiResolutionMode: false,
            serialNumber: serial,
            vendorID: 0x0001,
            productID: serial
        )

        store.mutate { config in
            config.displays.append(display)
            config.selectedDisplayID = display.id
        }
        try ensureAppRunning()
        printJSON(DisplayListItem(
            id: display.id,
            name: display.name,
            enabled: display.isEnabled,
            multiResolutionMode: display.multiResolutionMode
        ))

    case "preset":
        guard args.count > 5 else {
            fail("Usage: vdctl add preset <display> <name> <width> <height> <fps>")
        }
        guard let displayInfo = findDisplay(in: store.configuration, identifier: args[1]) else {
            fail("Display not found: \(args[1])")
        }
        let name = args[2]
        guard let width = Int(args[3]), let height = Int(args[4]), let fps = Int(args[5]) else {
            fail("Width, height and fps must be integers")
        }
        try DisplayEngine.validatePreset(name: name, width: width, height: height, refreshRate: fps)

        let preset = DisplayPreset(
            id: UUID().uuidString,
            name: name,
            width: width,
            height: height,
            refreshRate: fps,
            vendorID: 0x0001,
            productID: 0x0001
        )

        store.mutate { config in
            config.displays[displayInfo.index].presets.append(preset)
            if config.displays[displayInfo.index].multiResolutionMode {
                config.displays[displayInfo.index].activePresetIDs.insert(preset.id)
            } else {
                config.displays[displayInfo.index].activePresetIDs = [preset.id]
            }
        }
        try ensureAppRunning()
        printJSON(PresetListItem(
            id: preset.id,
            name: preset.name,
            width: preset.width,
            height: preset.height,
            refreshRate: preset.refreshRate,
            active: true
        ))

    default:
        fail("Unknown add target: \(subcommand)")
    }
}

private func handleRemove(args: [String], store: ConfigurationStore) throws {
    guard let subcommand = args.first else {
        fail("Usage: vdctl remove display <id-or-name> | vdctl remove preset ...")
    }

    switch subcommand {
    case "display":
        guard args.count > 1 else { fail("Usage: vdctl remove display <id-or-name>") }
        guard store.configuration.displays.count > 1 else { fail("Cannot remove the only display") }
        guard let displayInfo = findDisplay(in: store.configuration, identifier: args[1]) else {
            fail("Display not found: \(args[1])")
        }
        store.mutate { config in
            config.displays.remove(at: displayInfo.index)
            if config.selectedDisplayID == displayInfo.display.id {
                let newIndex = min(displayInfo.index, max(config.displays.count - 1, 0))
                config.selectedDisplayID = config.displays[newIndex].id
            }
        }
        try ensureAppRunning()
        printJSON(SuccessOutput(success: true))

    case "preset":
        guard args.count > 2 else {
            fail("Usage: vdctl remove preset <display> <preset-id-or-name>")
        }
        guard let displayInfo = findDisplay(in: store.configuration, identifier: args[1]) else {
            fail("Display not found: \(args[1])")
        }
        guard let presetInfo = findPreset(in: displayInfo.display, identifier: args[2]) else {
            fail("Preset not found: \(args[2])")
        }

        store.mutate { config in
            config.displays[displayInfo.index].presets.remove(at: presetInfo.index)
            config.displays[displayInfo.index].activePresetIDs.remove(presetInfo.preset.id)

            if config.displays[displayInfo.index].presets.isEmpty {
                let defaults = DisplayEngine.defaultPresets()
                config.displays[displayInfo.index].presets = defaults
                config.displays[displayInfo.index].activePresetIDs = [defaults[0].id]
            } else if config.displays[displayInfo.index].activePresetIDs.isEmpty {
                config.displays[displayInfo.index].activePresetIDs = [config.displays[displayInfo.index].presets[0].id]
            }
        }
        try ensureAppRunning()
        printJSON(SuccessOutput(success: true))

    default:
        fail("Unknown remove target: \(subcommand)")
    }
}

private func handleRename(args: [String], store: ConfigurationStore) throws {
    guard args.count > 1 else {
        fail("Usage: vdctl rename display <id-or-name> <new-name>")
    }
    guard let displayInfo = findDisplay(in: store.configuration, identifier: args[0]) else {
        fail("Display not found: \(args[0])")
    }
    let newName = args[1]
    guard DisplayEngine.isValidDisplayName(newName) else { fail("Invalid display name: \(newName)") }
    guard DisplayEngine.isDisplayNameUnique(newName, in: store.configuration.displays, excluding: displayInfo.display.id) else {
        fail("Display name already exists: \(newName)")
    }

    store.mutate { config in
        config.displays[displayInfo.index].name = newName
    }
    try ensureAppRunning()
    printJSON(DisplayListItem(
        id: displayInfo.display.id,
        name: newName,
        enabled: displayInfo.display.isEnabled,
        multiResolutionMode: displayInfo.display.multiResolutionMode
    ))
}

private func handleToggle(args: [String], store: ConfigurationStore) throws {
    guard args.count > 0 else { fail("Usage: vdctl toggle display <id-or-name>") }
    guard let displayInfo = findDisplay(in: store.configuration, identifier: args[0]) else {
        fail("Display not found: \(args[0])")
    }

    store.mutate { config in
        config.displays[displayInfo.index].isEnabled.toggle()
    }
    try ensureAppRunning()
    printJSON(DisplayListItem(
        id: displayInfo.display.id,
        name: store.configuration.displays[displayInfo.index].name,
        enabled: store.configuration.displays[displayInfo.index].isEnabled,
        multiResolutionMode: displayInfo.display.multiResolutionMode
    ))
}

private func handleActivate(args: [String], store: ConfigurationStore) throws {
    guard args.count > 1 else {
        fail("Usage: vdctl activate preset <display> <preset-id-or-name>")
    }
    guard let displayInfo = findDisplay(in: store.configuration, identifier: args[0]) else {
        fail("Display not found: \(args[0])")
    }
    guard let presetInfo = findPreset(in: displayInfo.display, identifier: args[1]) else {
        fail("Preset not found: \(args[1])")
    }

    store.mutate { config in
        if config.displays[displayInfo.index].multiResolutionMode {
            config.displays[displayInfo.index].activePresetIDs.insert(presetInfo.preset.id)
        } else {
            config.displays[displayInfo.index].activePresetIDs = [presetInfo.preset.id]
        }
    }
    try ensureAppRunning()
    printJSON(PresetSuccessOutput(
        success: true,
        displayID: displayInfo.display.id,
        activePresetIDs: Array(store.configuration.displays[displayInfo.index].activePresetIDs)
    ))
}

private func handleSet(args: [String], store: ConfigurationStore) throws {
    guard args.count > 2, args[0] == "multi-resolution" else {
        fail("Usage: vdctl set multi-resolution <display> <true|false>")
    }
    guard let displayInfo = findDisplay(in: store.configuration, identifier: args[1]) else {
        fail("Display not found: \(args[1])")
    }

    let enabled: Bool
    switch args[2].lowercased() {
    case "true", "1", "on", "yes": enabled = true
    case "false", "0", "off", "no": enabled = false
    default: fail("Invalid boolean value: \(args[2])")
    }

    store.mutate { config in
        config.displays[displayInfo.index].multiResolutionMode = enabled
        if !enabled && config.displays[displayInfo.index].activePresetIDs.count > 1 {
            if let firstActiveID = config.displays[displayInfo.index].presets.first(where: { config.displays[displayInfo.index].activePresetIDs.contains($0.id) })?.id {
                config.displays[displayInfo.index].activePresetIDs = [firstActiveID]
            }
        }
    }
    try ensureAppRunning()
    printJSON(DisplayListItem(
        id: displayInfo.display.id,
        name: displayInfo.display.name,
        enabled: displayInfo.display.isEnabled,
        multiResolutionMode: store.configuration.displays[displayInfo.index].multiResolutionMode
    ))
}

private func handleStatus(store: ConfigurationStore) {
    let engine = DisplayEngine.shared
    let displays = store.configuration.displays.map { config in
        DisplayStatus(
            id: config.id,
            name: config.name,
            enabled: config.isEnabled,
            online: engine.isOnline(config),
            multiResolutionMode: config.multiResolutionMode,
            activePresetIDs: Array(config.activePresetIDs)
        )
    }
    printJSON(StatusOutput(
        appRunning: isAppRunning(),
        version: store.configuration.version,
        selectedDisplayID: store.configuration.selectedDisplayID,
        displays: displays
    ))
}

private func printUsage() {
    print("""
    vdctl — VirtualDisplay command line interface

    Usage:
      vdctl list displays
      vdctl list presets <display-id-or-name>

      vdctl add display <name>
      vdctl remove display <id-or-name>
      vdctl rename display <id-or-name> <new-name>
      vdctl toggle display <id-or-name>

      vdctl add preset <display-id-or-name> <name> <width> <height> <fps>
      vdctl remove preset <display-id-or-name> <preset-id-or-name>
      vdctl activate preset <display-id-or-name> <preset-id-or-name>

      vdctl set multi-resolution <display-id-or-name> <true|false>

      vdctl status
      vdctl help
    """)
}

// MARK: - Entry

private func run() throws {
    let args = CommandLine.arguments
    guard args.count > 1 else {
        printUsage()
        return
    }

    let store = ConfigurationStore()
    store.load()

    let command = args[1]
    let remaining = Array(args.dropFirst(2))

    switch command {
    case "list":
        try handleList(args: remaining, store: store)
    case "add":
        try handleAdd(args: remaining, store: store)
    case "remove":
        try handleRemove(args: remaining, store: store)
    case "rename":
        try handleRename(args: Array(remaining.dropFirst()), store: store)
    case "toggle":
        try handleToggle(args: Array(remaining.dropFirst()), store: store)
    case "activate":
        try handleActivate(args: Array(remaining.dropFirst()), store: store)
    case "set":
        try handleSet(args: remaining, store: store)
    case "status":
        handleStatus(store: store)
    case "help", "--help", "-h":
        printUsage()
    default:
        fail("Unknown command: \(command)")
    }
}

do {
    try run()
} catch {
    fail(error.localizedDescription)
}
