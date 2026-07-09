import Foundation
import LumiCoreKit
import SuperLogKit

/// 激活防休眠工具
///
/// 通过 IOKit 电源断言阻止系统进入休眠状态，
/// 可选择是否同时阻止屏幕休眠，以及设置持续时间。
struct CaffeinateActivateTool: LumiAgentTool, SuperLog {
    nonisolated static let emoji = "☕️"
    nonisolated static let verbose: Bool = true

    static let info = LumiAgentToolInfo(
        id: "caffeinate_activate",
        displayName: "Activate Caffeinate",
        description: "Activate caffeinate to prevent the system from sleeping. Supports two modes: 'systemAndDisplay' (prevent both system and display sleep, keep screen on) and 'systemOnly' (prevent system sleep but allow display to turn off). Supports timed duration or indefinite activation."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "mode": .object([
                    "type": .string("string"),
                    "description": .string("Sleep prevention mode: 'systemAndDisplay' (default, prevents system sleep and keeps screen on) or 'systemOnly' (prevents system sleep but allows screen to turn off)"),
                    "enum": .array([.string("systemOnly"), .string("systemAndDisplay")]),
                ]),
                "duration": .object([
                    "type": .string("number"),
                    "description": .string("Duration in seconds. 0 means indefinite (default: 0). Common values: 600 (10 min), 3600 (1 hour), 7200 (2 hours), 18000 (5 hours)."),
                ]),
            ]),
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String { "阻止系统睡眠" }
    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let modeString = arguments.string("mode") ?? "systemAndDisplay"
        let duration = arguments.double("duration") ?? 0

        let mode: CaffeinateManager.SleepMode
        switch modeString {
        case "systemOnly":
            mode = .systemOnly
        default:
            mode = .systemAndDisplay
        }

        if Self.verbose {
            if CaffeinatePlugin.verbose {
                            CaffeinatePlugin.logger.info("\(Self.t)Activating caffeinate: mode=\(mode.rawValue), duration=\(duration)s")
            }
        }

        let manager = CaffeinateManager.shared

        if manager.isActive {
            // Already active — deactivate first, then reactivate with new params
            manager.deactivate()
        }

        manager.activate(mode: mode, duration: duration)

        let modeDisplay = mode == .systemAndDisplay
            ? "System & Display (prevent sleep, keep screen on)"
            : "System Only (prevent sleep, allow screen off)"
        let durationDisplay = duration > 0 ? formatDuration(duration) : "Indefinite"

        return """
        ## Caffeinate Activated ✅
        
        - **Mode**: \(modeDisplay)
        - **Duration**: \(durationDisplay)
        - **Started**: \(Date().formatted(date: .omitted, time: .standard))
        
        System will stay awake. Use `caffeinate_deactivate` to stop, or `caffeinate_status` to check current state.
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
