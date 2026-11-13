import Foundation
import KitAgentTool
import PluginDevice

/// 在聊天消息区查询设备状态并展示卡片的工具。
///
/// LLM 调用本工具后：
/// 1. 工具采集一份设备状态快照（按 `scope` 裁剪）；
/// 2. 工具把快照转成一条带 `renderKind = "device-status"` 的时间线消息；
/// 3. 插件注册的渲染器把这条消息画成一张设备状态卡片；
/// 4. 工具同时把关键数值以文本形式返回给 LLM，供模型在回复里引用。
///
/// 卡片消息只用于界面展示，不会回流到 LLM 上下文（`MessageTimelineEvent`
/// 会把它过滤掉）；返回给模型的文本是另一条独立通路。
public struct DeviceStatusTool: SuperAgentTool, @unchecked Sendable {
    /// 工具名（唯一标识符，不翻译）。
    public static let toolName = "device_status"

    public let name = Self.toolName

    /// 插入卡片消息的桥。由插件在 `onBoot` 时创建并注入。
    private let bridge: DeviceStatusMessageBridge

    /// 采集器。由插件在 `onBoot` 时创建并注入。
    private let collector: DeviceStatusCollector

    /// 构造工具。
    ///
    /// 保持 internal：`DeviceStatusCollector` 是插件内部实现，
    /// 不该成为这个包的公共 API 面。
    init(bridge: DeviceStatusMessageBridge, collector: DeviceStatusCollector) {
        self.bridge = bridge
        self.collector = collector
    }

    public func description(for language: LanguagePreference) -> String {
        "Query the current device status (CPU, memory, GPU, battery, disk, temperature, processes) and show it as a card in the chat. Use this when the user asks how the machine is doing, what is using resources, or about device health."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let scope = Self.scope(from: arguments) else {
            return "查询设备状态"
        }
        return "查询设备状态：\(scope.displayName)"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "scope": [
                    "type": "string",
                    "enum": DeviceStatusScope.allCases.map(\.rawValue),
                    "description": "Which metrics to report. 'overview' shows CPU, memory, GPU, battery and disk at a glance. Defaults to 'overview'.",
                ],
            ],
            "required": [],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        // 只读取本机指标，不写文件、不联网，风险很低。
        .low
    }

    /// 无会话上下文的执行入口。
    ///
    /// 拿不到会话信息时不插入时间线消息——避免把消息写进一个不存在的会话里。
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await run(arguments: arguments, timeline: nil).content
    }

    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        try await run(arguments: arguments, timeline: nil)
    }

    /// 带会话上下文的结构化执行入口。
    ///
    /// 借 `ToolExecutionContext` 拿到会话与回合 ID，插入一条结构化时间线消息，
    /// 让用户拿到一张可视化的设备状态卡片。
    /// 时间线消息只用于界面展示，不会回流到 LLM 上下文。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        try await run(
            arguments: arguments,
            timeline: DeviceStatusTimelineContext(
                conversationID: context.conversationID,
                turnID: context.turnID
            )
        )
    }

    // MARK: - Core

    /// 工具的核心流程。
    ///
    /// - Parameters:
    ///   - arguments: 工具参数。
    ///   - timeline: 会话上下文；为 nil 时不产生时间线消息。
    /// - Returns: 工具结果。
    private func run(
        arguments: [String: ToolArgument],
        timeline: DeviceStatusTimelineContext?
    ) async throws -> ToolCallResult {
        let scope = try Self.resolveScope(from: arguments)

        // `collector` 与 `bridge` 都是 @MainActor 类型，直接 await 即可。
        let payload = await collector.collect(scope: scope)

        if let timeline {
            await bridge.insert(
                conversationID: timeline.conversationID,
                turnID: timeline.turnID,
                payload: payload
            )
        }

        return ToolCallResult(content: Self.summary(for: payload))
    }

    // MARK: - Arguments

    /// 解析 `scope` 参数。
    ///
    /// 参数缺失时回退到 `overview`；参数存在但不是合法范围时抛错——
    /// 非法输入必须让模型知道，而不是悄悄换一个范围继续跑。
    static func resolveScope(from arguments: [String: ToolArgument]) throws -> DeviceStatusScope {
        guard let raw = arguments["scope"]?.value as? String else {
            return .overview
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .overview
        }
        guard let scope = DeviceStatusScope(rawValue: trimmed.lowercased()) else {
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "Unknown scope '\(raw)'. Valid scopes: \(DeviceStatusScope.allCases.map(\.rawValue).joined(separator: ", "))."
            )
        }
        return scope
    }

    /// 宽松解析 `scope` 参数；无法解析时返回 nil。
    ///
    /// 供展示描述使用——展示文案不该因为参数非法而让整次调用失败。
    static func scope(from arguments: [String: ToolArgument]) -> DeviceStatusScope? {
        guard let raw = arguments["scope"]?.value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return DeviceStatusScope(rawValue: trimmed.lowercased())
    }

    // MARK: - Summary

    /// 生成给 LLM 的结果文本。
    ///
    /// 只包含模型在回复里真正需要的数值；详细布局交给卡片。
    static func summary(for payload: DeviceStatusPayload) -> String {
        var lines: [String] = []
        lines.append("Device status for \(payload.device.name) (\(payload.device.osVersion)):")

        if let cpu = payload.cpu {
            var line = "CPU \(Int(cpu.usagePercentage.rounded()))%"
            if !cpu.loadAverage.isEmpty {
                let load = cpu.loadAverage.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: "/")
                line += ", load \(load)"
            }
            lines.append(line)
        }

        if let memory = payload.memory {
            lines.append(
                "Memory \(formatBytes(memory.usedBytes)) / \(formatBytes(memory.totalBytes)) (\(Int(memory.usagePercentage.rounded()))%, pressure \(memory.pressure))"
            )
        }

        if let gpu = payload.gpu {
            var line = "GPU \(Int(gpu.utilizationPercentage.rounded()))%"
            if gpu.totalMemoryBytes > 0 {
                line += ", VRAM \(formatBytes(gpu.usedMemoryBytes)) / \(formatBytes(gpu.totalMemoryBytes))"
            }
            if gpu.temperatureCelsius > 0 {
                line += ", \(Int(gpu.temperatureCelsius.rounded()))°C"
            }
            lines.append(line)
        }

        if let battery = payload.battery, battery.hasBattery {
            var line = "Battery \(Int((battery.level * 100).rounded()))%"
            if battery.isCharging {
                line += " (charging)"
            } else if battery.isCharged {
                line += " (full)"
            }
            lines.append(line)
        }

        if !payload.volumes.isEmpty {
            for volume in payload.volumes {
                lines.append(
                    "Disk \(volume.name): \(formatBytes(volume.usedBytes)) / \(formatBytes(volume.totalBytes)) used, \(formatBytes(volume.availableBytes)) free"
                )
            }
        }

        if let thermal = payload.thermal {
            if let peak = thermal.peakCelsius {
                lines.append("Temperature peak \(String(format: "%.1f", peak))°C across \(thermal.readings.count) sensors")
            } else {
                lines.append("Temperature: no sensor readings available")
            }
        }

        if !payload.processes.isEmpty {
            lines.append("Top processes:")
            for process in payload.processes {
                lines.append(
                    "- \(process.name) (pid \(process.pid)): CPU \(String(format: "%.1f", process.cpuPercentage))%, memory \(formatBytes(process.memoryBytes))"
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    /// 把字节数格式化成可读文本。
    static func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }

    /// 把字节数格式化成可读文本。
    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
}

/// 设备状态卡片时间线消息的会话上下文。
///
/// 工具只有在拿到真实会话信息时才插入时间线消息；拿不到就不插入，
/// 避免把消息写进一个不存在的会话。
struct DeviceStatusTimelineContext: Sendable {
    let conversationID: UUID
    let turnID: UUID?

    init(conversationID: UUID, turnID: UUID?) {
        self.conversationID = conversationID
        self.turnID = turnID
    }
}
