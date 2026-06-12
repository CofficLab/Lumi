import Foundation
import AgentToolKit
import SuperLogKit

/// 防休眠并立即关闭屏幕工具
///
/// 激活系统防休眠（仅系统级别，允许屏幕休眠），然后立刻关闭屏幕。
/// 适用于后台下载等需要保持系统运行但不需要屏幕的场景。
struct CaffeinateTurnOffDisplayTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔌"
    nonisolated static let verbose: Bool = false

    let name = "caffeinate_turn_off_display"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "防止系统睡眠并立即关闭显示器。适用于下载等需要系统保持唤醒但不需要屏幕的后台任务。系统会保持唤醒，同时关闭显示器以节省电量。"
        case .english:
            return "Prevent system sleep and immediately turn off the display. Useful for background tasks like downloads that need the system awake but don't require the screen. The system will stay awake while the display turns off to save power."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "duration": [
                    "type": "number",
                    "description": "Duration in seconds. 0 means indefinite (default: 0). Common values: 600 (10 min), 3600 (1 hour), 7200 (2 hours), 18000 (5 hours).",
                ],
            ],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {        "关闭显示器"    }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let duration = arguments["duration"]?.value as? TimeInterval ?? 0

        if Self.verbose {
            if CaffeinatePlugin.verbose {
                            CaffeinatePlugin.logger.info("\(Self.t)Activating caffeinate with display off, duration=\(duration)s")
            }
        }

        let manager = CaffeinateManager.shared

        if manager.isActive {
            manager.deactivate()
        }

        manager.activateAndTurnOffDisplay(duration: duration)

        let durationDisplay = duration > 0 ? formatDuration(duration) : "Indefinite"

        return """
        ## Caffeinate Activated (Display Off) ✅
        
        - **Mode**: System Only (display turned off)
        - **Duration**: \(durationDisplay)
        - **Started**: \(Date().formatted(date: .omitted, time: .standard))
        
        System will stay awake with the display off. Use `caffeinate_deactivate` to stop, or `caffeinate_status` to check current state.
        """
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds >= 3600 {
            let hours = Int(seconds) / 3600
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            let minutes = Int(seconds) / 60
            return "\(minutes) minute\(minutes > 1 ? "s" : "")"
        }
    }
}
