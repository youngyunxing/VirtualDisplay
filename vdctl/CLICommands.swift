import Foundation

enum CLICommand: Equatable {
    case listDisplays
    case listPresets(displayIdentifier: String)
    case addDisplay(name: String)
    case addPreset(displayIdentifier: String, name: String, width: Int, height: Int, refreshRate: Int)
    case removeDisplay(identifier: String)
    case removePreset(displayIdentifier: String, presetIdentifier: String)
    case renameDisplay(identifier: String, newName: String)
    case toggleDisplay(identifier: String)
    case activatePreset(displayIdentifier: String, presetIdentifier: String)
    case setMultiResolution(displayIdentifier: String, enabled: Bool)
    case status
    case help
}

enum CLICommandError: Error, Equatable {
    case message(String)
}

func parseBoolean(_ value: String) -> Bool? {
    switch value.lowercased() {
    case "true", "1", "on", "yes": return true
    case "false", "0", "off", "no": return false
    default: return nil
    }
}

func parseCLICommand(arguments: [String]) -> Result<CLICommand, CLICommandError> {
    guard let command = arguments.first else {
        return .success(.help)
    }

    let args = Array(arguments.dropFirst())

    switch command {
    case "list":
        guard let subcommand = args.first else {
            return .failure(.message("Usage: vdctl list displays | vdctl list presets <display>"))
        }
        switch subcommand {
        case "displays":
            return .success(.listDisplays)
        case "presets":
            guard args.count > 1 else { return .failure(.message("Missing display identifier")) }
            return .success(.listPresets(displayIdentifier: args[1]))
        default:
            return .failure(.message("Unknown list target: \(subcommand)"))
        }

    case "add":
        guard let subcommand = args.first else {
            return .failure(.message("Usage: vdctl add display <name> | vdctl add preset ..."))
        }
        switch subcommand {
        case "display":
            guard args.count > 1 else { return .failure(.message("Usage: vdctl add display <name>")) }
            return .success(.addDisplay(name: args[1]))
        case "preset":
            guard args.count > 5 else {
                return .failure(.message("Usage: vdctl add preset <display> <name> <width> <height> <fps>"))
            }
            guard let width = Int(args[3]), let height = Int(args[4]), let fps = Int(args[5]) else {
                return .failure(.message("Width, height and fps must be integers"))
            }
            return .success(.addPreset(
                displayIdentifier: args[1],
                name: args[2],
                width: width,
                height: height,
                refreshRate: fps
            ))
        default:
            return .failure(.message("Unknown add target: \(subcommand)"))
        }

    case "remove":
        guard let subcommand = args.first else {
            return .failure(.message("Usage: vdctl remove display <id-or-name> | vdctl remove preset ..."))
        }
        switch subcommand {
        case "display":
            guard args.count > 1 else { return .failure(.message("Usage: vdctl remove display <id-or-name>")) }
            return .success(.removeDisplay(identifier: args[1]))
        case "preset":
            guard args.count > 2 else {
                return .failure(.message("Usage: vdctl remove preset <display> <preset-id-or-name>"))
            }
            return .success(.removePreset(displayIdentifier: args[1], presetIdentifier: args[2]))
        default:
            return .failure(.message("Unknown remove target: \(subcommand)"))
        }

    case "rename":
        let subArgs = Array(args.dropFirst())
        guard subArgs.count > 1 else {
            return .failure(.message("Usage: vdctl rename display <id-or-name> <new-name>"))
        }
        return .success(.renameDisplay(identifier: subArgs[0], newName: subArgs[1]))

    case "toggle":
        let subArgs = Array(args.dropFirst())
        guard subArgs.count > 0 else { return .failure(.message("Usage: vdctl toggle display <id-or-name>")) }
        return .success(.toggleDisplay(identifier: subArgs[0]))

    case "activate":
        let subArgs = Array(args.dropFirst())
        guard subArgs.count > 1 else {
            return .failure(.message("Usage: vdctl activate preset <display> <preset-id-or-name>"))
        }
        return .success(.activatePreset(displayIdentifier: subArgs[0], presetIdentifier: subArgs[1]))

    case "set":
        guard args.count > 2, args[0] == "multi-resolution" else {
            return .failure(.message("Usage: vdctl set multi-resolution <display> <true|false>"))
        }
        guard let enabled = parseBoolean(args[2]) else {
            return .failure(.message("Invalid boolean value: \(args[2])"))
        }
        return .success(.setMultiResolution(displayIdentifier: args[1], enabled: enabled))

    case "status":
        return .success(.status)

    case "help", "--help", "-h":
        return .success(.help)

    default:
        return .failure(.message("Unknown command: \(command)"))
    }
}
