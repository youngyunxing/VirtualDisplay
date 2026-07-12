import Foundation

/// 诊断报告：汇总版本、系统、显示器状态与近 24 小时日志。
/// App 的「导出诊断信息」菜单项与 `vdctl diagnostics` 共用此实现。
public enum DiagnosticsReport {
    public static func build(store: ConfigurationStore, engine: DisplayEngine, appVersion: String) -> String {
        var lines: [String] = []
        lines.append("VirtualDisplay Diagnostics")
        lines.append("Generated: \(Date())")
        lines.append("App Version: v\(appVersion)")
        lines.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("")
        lines.append("== Displays ==")
        for config in store.configuration.displays {
            let online = engine.isOnline(config)
            let mode = engine.currentMode(for: config)
            let modeDesc = mode.map { "\($0.logicalWidth)x\($0.logicalHeight)@\(Int($0.refreshRate))Hz" } ?? "-"
            let errorDesc = engine.lastError(for: config.id)?.localizedDescription ?? "-"
            lines.append("- \(config.name): enabled=\(config.isEnabled) online=\(online) mode=\(modeDesc) multiResolution=\(config.multiResolutionMode) lastError=\(errorDesc)")
        }
        lines.append("")
        lines.append("== Logs (last 24h, subsystem com.youngyunxing.VirtualDisplay) ==")
        lines.append(collectLogOutput())
        return lines.joined(separator: "\n")
    }

    private static func collectLogOutput() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show",
            "--predicate", "subsystem == \"com.youngyunxing.VirtualDisplay\"",
            "--last", "24h",
            "--style", "compact",
            "--info"
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return output.isEmpty ? "(no log entries)" : output
        } catch {
            return "(failed to collect logs: \(error.localizedDescription))"
        }
    }
}
