import Foundation
import os.log

final class LaunchAgentManager {
    static let shared = LaunchAgentManager()

    private let logger = Logger(subsystem: "com.youngyunxing.VirtualDisplay", category: "LaunchAgent")
    private let label = "com.youngyunxing.VirtualDisplay"

    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    private var executablePath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/VirtualDisplay").path
    }

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    @discardableResult
    func enable() -> Bool {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: plistURL)
        } catch {
            logger.error("Failed to write launch agent plist: \(error.localizedDescription)")
            return false
        }

        return runLaunchctl(arguments: ["load", plistURL.path])
    }

    @discardableResult
    func disable() -> Bool {
        _ = runLaunchctl(arguments: ["unload", plistURL.path])

        do {
            try FileManager.default.removeItem(at: plistURL)
        } catch {
            logger.error("Failed to remove launch agent plist: \(error.localizedDescription)")
        }
        return true
    }

    private func runLaunchctl(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            logger.error("launchctl failed: \(error.localizedDescription)")
            return false
        }
    }
}
