import Foundation

/// 查询防休眠状态工具
///
/// 返回当前防休眠的激活状态、模式、持续时间、已激活时长等信息。
struct CaffeinateStatusTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false

    let name = "caffeinate_status"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查询当前 caffeinate 状态。返回是否激活、当前模式、持续时间、已用时间和剩余时间。"
        case .english:
            return "Query the current caffeinate status. Returns whether caffeinate is active, the current mode, duration, elapsed time, and remaining time."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let manager = CaffeinateManager.shared

        if Self.verbose {
            if CaffeinatePlugin.verbose {
                            CaffeinatePlugin.logger.info("\(Self.t)Querying caffeinate status")
            }
        }

        guard manager.isActive else {
            return """
            ## Caffeinate Status
            
            - **Active**: No ❌
            
            System follows normal sleep policy. Use `caffeinate_activate` to prevent sleep.
            """
        }

        let mode: String
        switch manager.mode {
        case .systemAndDisplay:
            mode = "System & Display (prevent sleep, keep screen on)"
        case .systemOnly:
            mode = "System Only (prevent sleep, allow screen off)"
        }

        let elapsed = manager.getActiveDuration()
        let elapsedDisplay = elapsed.map { formatDuration($0) } ?? "Unknown"

        var remainingDisplay = "Indefinite"
        if manager.duration > 0, let elapsed = elapsed {
            let remaining = max(0, manager.duration - elapsed)
            remainingDisplay = formatDuration(remaining)
        }

        return """
        ## Caffeinate Status
        
        - **Active**: Yes ✅
        - **Mode**: \(mode)
        - **Duration**: \(manager.duration > 0 ? formatDuration(manager.duration) : "Indefinite")
        - **Active Since**: \(elapsedDisplay) ago
        - **Remaining**: \(remainingDisplay)
        """
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
