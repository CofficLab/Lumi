import Foundation
import KitAgentTool
import ProviderMessage
import ProviderMessageRendering
import Testing
@testable import PluginDevice

/// 设备状态工具与卡片渲染器的注册链路。
@Suite("DeviceStatus 工具与渲染器")
@MainActor
struct DeviceStatusToolTests {

    // MARK: - Scope 解析

    @Test("scope 缺失时回退到总览")
    func missingScopeFallsBackToOverview() throws {
        let scope = try DeviceStatusTool.resolveScope(from: [:])
        #expect(scope == .overview)
    }

    @Test("scope 为空串时回退到总览")
    func blankScopeFallsBackToOverview() throws {
        let scope = try DeviceStatusTool.resolveScope(from: ["scope": ToolArgument("   ")])
        #expect(scope == .overview)
    }

    @Test("合法 scope 被正确解析，且忽略大小写")
    func validScopeIsParsed() throws {
        #expect(try DeviceStatusTool.resolveScope(from: ["scope": ToolArgument("cpu")]) == .cpu)
        #expect(try DeviceStatusTool.resolveScope(from: ["scope": ToolArgument("MEMORY")]) == .memory)
        #expect(try DeviceStatusTool.resolveScope(from: ["scope": ToolArgument(" processes ")]) == .processes)
    }

    /// 非法 scope 必须抛错，不能悄悄换一个范围继续跑——
    /// 否则模型以为自己拿到的是「内存」，实际拿到的是「总览」。
    @Test("非法 scope 抛出工具执行错误")
    func invalidScopeThrows() {
        #expect(throws: ToolExecutionError.self) {
            try DeviceStatusTool.resolveScope(from: ["scope": ToolArgument("disk")])
        }
    }

    @Test("宽松解析在非法值时返回 nil")
    func lenientScopeReturnsNilForInvalidValue() {
        #expect(DeviceStatusTool.scope(from: ["scope": ToolArgument("disk")]) == nil)
        #expect(DeviceStatusTool.scope(from: [:]) == nil)
        #expect(DeviceStatusTool.scope(from: ["scope": ToolArgument("cpu")]) == .cpu)
    }

    // MARK: - 工具元信息

    @Test("工具名固定为 device_status")
    func toolNameIsStable() {
        #expect(DeviceStatusTool.toolName == "device_status")
    }

    @Test("input schema 声明了全部合法 scope")
    func inputSchemaDeclaresAllScopes() {
        let tool = DeviceStatusTool(
            bridge: DeviceStatusMessageBridge(),
            collector: DeviceStatusCollector()
        )
        let schema = tool.inputSchema(for: .english)
        let properties = schema["properties"] as? [String: Any]
        let scope = properties?["scope"] as? [String: Any]
        let enumValues = scope?["enum"] as? [String]

        #expect(enumValues == DeviceStatusScope.allCases.map(\.rawValue))
    }

    @Test("工具是低风险只读操作")
    func toolIsLowRisk() {
        let tool = DeviceStatusTool(
            bridge: DeviceStatusMessageBridge(),
            collector: DeviceStatusCollector()
        )
        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
    }

    // MARK: - 渲染器

    /// 卡片消息是 `role = .system`，渲染器优先级低于核心的
    /// `core-system-message`（base + 150 = 160）就会被通用渲染器接管，
    /// 用户看到的是一行纯文本而不是卡片。
    @Test("渲染器优先级高于核心系统消息渲染器")
    func rendererOutranksCoreSystemMessage() {
        #expect(DevicePlugin.cardRendererOrder > 160)
    }

    @Test("渲染器只认设备状态卡片消息")
    func rendererOnlyHandlesDeviceStatusMessages() {
        let item = DeviceStatusCardRenderer.item(order: DevicePlugin.cardRendererOrder)

        let cardMessage = DeviceStatusTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: DeviceStatusTimelineTests.makePayload()
        )
        #expect(item.canRender(cardMessage))

        let plainMessage = Message(
            conversationID: UUID(),
            role: .system,
            content: "hello"
        )
        #expect(!item.canRender(plainMessage))
    }

    @Test("渲染器 ID 与时间线消息一致")
    func rendererIDMatchesTimeline() {
        let item = DeviceStatusCardRenderer.item(order: DevicePlugin.cardRendererOrder)
        #expect(item.id == DeviceStatusTimeline.rendererID)
    }

    // MARK: - 摘要文本

    @Test("摘要文本包含各指标的关键数值")
    func summaryIncludesKeyMetrics() {
        let summary = DeviceStatusTool.summary(for: DeviceStatusTimelineTests.makePayload())

        #expect(summary.contains("Test Mac"))
        #expect(summary.contains("CPU 43%"))
        #expect(summary.contains("Memory"))
        #expect(summary.contains("55%"))
        #expect(summary.contains("GPU 12%"))
        #expect(summary.contains("Battery 72%"))
        #expect(summary.contains("Macintosh HD"))
        #expect(summary.contains("Safari"))
    }

    @Test("摘要在无数据时不编造指标")
    func summaryOmitsAbsentMetrics() {
        let payload = DeviceStatusPayload(
            scope: .thermal,
            timestamp: 0,
            device: DeviceIdentity(
                name: "Test Mac",
                osVersion: "macOS 15.1.0",
                processorName: "",
                physicalCoreCount: 1,
                logicalCoreCount: 1,
                uptime: 0
            )
        )
        let summary = DeviceStatusTool.summary(for: payload)

        #expect(!summary.contains("CPU"))
        #expect(!summary.contains("Memory"))
        #expect(!summary.contains("GPU"))
        #expect(!summary.contains("Battery"))
    }

    @Test("温度无读数时摘要如实说明")
    func summaryReportsMissingThermalReadings() {
        let payload = DeviceStatusPayload(
            scope: .thermal,
            timestamp: 0,
            device: DeviceIdentity(
                name: "Test Mac",
                osVersion: "macOS 15.1.0",
                processorName: "",
                physicalCoreCount: 1,
                logicalCoreCount: 1,
                uptime: 0
            ),
            thermal: DeviceThermalStatus(readings: [], peakCelsius: nil)
        )
        let summary = DeviceStatusTool.summary(for: payload)

        #expect(summary.contains("no sensor readings"))
    }

    // MARK: - 字节格式化

    @Test("字节格式化不会溢出")
    func byteFormattingHandlesExtremeValues() {
        #expect(!DeviceStatusTool.formatBytes(UInt64.max).isEmpty)
        #expect(!DeviceStatusTool.formatBytes(Int64.min).isEmpty)
        #expect(DeviceStatusTool.formatBytes(UInt64(0)) == "Zero KB")
    }
}
