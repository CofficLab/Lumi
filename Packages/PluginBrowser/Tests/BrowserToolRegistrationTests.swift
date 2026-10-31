import Foundation
import KernelCore
import KitAgentTool
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderToolManager
import SwiftUI
import Testing
@testable import BrowserPlugin

/// 插件装配的集成测试。
///
/// 验证「onBoot 注册了什么、onShutdown 注销了什么」——工具漏注册是这类
/// 插件最容易犯且最难发现的错误：代码能编译、能跑，但 LLM 根本看不到那个工具。
@Suite("PluginBrowser 工具装配")
@MainActor
struct BrowserToolRegistrationTests {
    /// 期望注册的工具名。
    private static let expectedToolNames = [
        "browser_open",
        "browser_snapshot",
        "browser_read",
        "browser_status",
        "browser_interact",
        "browser_wait",
        "browser_screenshot",
        "browser_navigate",
        "browser_evaluate",
    ]

    /// 启动一个只注册了必要 Provider 的内核。
    private func makeKernel() throws -> (KernelCoreContainer, DefaultToolManagerProviding) {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let toolManager = DefaultToolManagerProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, DefaultChatSectionProviding())
        try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
        try kernel.registerProvider((any RootViewProviding).self, DefaultRootViewProviding())
        try kernel.registerProvider((any RailViewProviding).self, DefaultRailViewProviding())
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        return (kernel, toolManager)
    }

    @Test("onBoot 注册全部 9 个浏览器工具")
    func registersAllTools() throws {
        let (kernel, toolManager) = try makeKernel()
        let plugin = BrowserPlugin()
        try plugin.onBoot(kernel: kernel)

        for name in Self.expectedToolNames {
            #expect(toolManager.tool(named: name) != nil, "工具 \(name) 未注册")
        }
        #expect(toolManager.tool(named: "browser_snapshot") != nil)
        #expect(toolManager.tool(named: "browser_wait") != nil)
        #expect(toolManager.tool(named: "browser_screenshot") != nil)
        #expect(toolManager.tool(named: "browser_navigate") != nil)
        #expect(toolManager.tool(named: "browser_evaluate") != nil)
    }

    @Test("全部工具归到 Browser 插件分组")
    func groupsToolsUnderBrowserPlugin() throws {
        let (kernel, toolManager) = try makeKernel()
        let plugin = BrowserPlugin()
        try plugin.onBoot(kernel: kernel)

        let groups = toolManager.toolsGroupedByPlugin()
        let browserGroup = groups.first { $0.pluginID == "Browser" }
        #expect(browserGroup != nil)

        let names = Set(browserGroup?.tools.map(\.name) ?? [])
        for name in Self.expectedToolNames {
            #expect(names.contains(name), "工具 \(name) 未归入 Browser 分组")
        }
    }

    @Test("onShutdown 注销全部浏览器工具")
    func removesAllToolsOnShutdown() throws {
        let (kernel, toolManager) = try makeKernel()
        let plugin = BrowserPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        for name in Self.expectedToolNames {
            #expect(toolManager.tool(named: name) == nil, "工具 \(name) 未被注销")
        }
    }

    @Test("工具的风险等级符合预期")
    func riskLevelsAreAppropriate() throws {
        let manager = BrowserSessionManager()

        // 只读的工具不应触发审批。
        #expect(BrowserSnapshotTool(sessions: manager).permissionRiskLevel(arguments: [:]) == .low)
        #expect(BrowserReadTool(sessions: manager).permissionRiskLevel(arguments: [:]) == .low)
        #expect(BrowserStatusTool(sessions: manager).permissionRiskLevel(arguments: [:]) == .low)
        #expect(BrowserWaitTool(sessions: manager).permissionRiskLevel(arguments: [:]) == .low)
        #expect(BrowserScreenshotTool(sessions: manager).permissionRiskLevel(arguments: [:]) == .low)

        // 会改变页面状态或执行代码的工具必须审批。
        #expect(BrowserInteractTool(sessions: manager).permissionRiskLevel(arguments: [:]) == .high)
        #expect(BrowserEvaluateTool(sessions: manager).permissionRiskLevel(arguments: [:]) == .medium)

        // 打开本地地址需要审批，普通地址不需要。
        let openTool = BrowserOpenTool(sessions: manager)
        #expect(openTool.permissionRiskLevel(arguments: ["url": ToolArgument("https://example.com")]) == .low)
        #expect(openTool.permissionRiskLevel(arguments: ["url": ToolArgument("http://localhost:8080")]) == .high)
        #expect(openTool.permissionRiskLevel(arguments: ["url": ToolArgument("http://192.168.1.10")]) == .high)
    }

    @Test("只有读工具可以并行执行")
    func executionCapabilitiesAreCorrect() {
        let manager = BrowserSessionManager()

        #expect(BrowserSnapshotTool(sessions: manager).executionCapability == .parallelReadOnly)
        #expect(BrowserReadTool(sessions: manager).executionCapability == .parallelReadOnly)
        #expect(BrowserStatusTool(sessions: manager).executionCapability == .parallelReadOnly)
        #expect(BrowserWaitTool(sessions: manager).executionCapability == .parallelReadOnly)
        #expect(BrowserScreenshotTool(sessions: manager).executionCapability == .parallelReadOnly)

        #expect(BrowserInteractTool(sessions: manager).executionCapability == .interactive)
        #expect(BrowserOpenTool(sessions: manager).executionCapability == .serialSideEffect)
        #expect(BrowserNavigateTool(sessions: manager).executionCapability == .serialSideEffect)
        #expect(BrowserEvaluateTool(sessions: manager).executionCapability == .serialSideEffect)
    }
}
