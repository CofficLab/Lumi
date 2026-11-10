import Foundation
import KernelCore
import KitAgentTool
import KitLLM
import ProviderLLMManager
import ProviderMessageRendering
import ProviderToolManager
import Testing
@testable import PluginToolLLMProvider

/// 插件的装配行为：工具与渲染器都要注册进内核，并且能在停用时撤回。
@MainActor
struct PluginLLMProviderToolPluginTests {

    /// 只实现注册与查询的最小工具管理器。
    @MainActor
    private final class MockToolManager: ToolManagerProviding {
        private var tools: [String: any SuperAgentTool] = [:]
        private var order: [String] = []

        func allTools() -> [any SuperAgentTool] {
            order.compactMap { tools[$0] }
        }

        func add(_ tool: any SuperAgentTool, pluginID: String) {
            if tools[tool.name] == nil { order.append(tool.name) }
            tools[tool.name] = tool
        }

        func remove(id: String) {
            tools.removeValue(forKey: id)
            order.removeAll { $0 == id }
        }

        func tool(named name: String) -> (any SuperAgentTool)? { tools[name] }

        func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] {
            allTools().map { (pluginID: "mock", tools: [$0]) }
        }

        func displayDescription(for toolCall: KitAgentTool.ToolCall) -> String? { nil }
        func riskLevel(for toolCall: KitAgentTool.ToolCall) -> CommandRiskLevel? { .low }

        @discardableResult
        func addToolManagerObserver(
            _ callback: @escaping (ToolManagerEvent) -> Void
        ) -> any ToolManagerObserverHandle { NoopHandle() }

        @discardableResult
        func addToolJobObserver(
            _ callback: @escaping (ToolJobEvent) -> Void
        ) -> any ToolJobObserverHandle { NoopHandle() }

        func submit(
            _ toolCalls: [KitAgentTool.ToolCall],
            policy: ToolExecutionPolicy,
            conversationID: UUID,
            turnID: UUID?
        ) -> [ToolJob] { [] }

        func execute(
            _ toolCall: KitAgentTool.ToolCall,
            conversationID: UUID,
            turnID: UUID?
        ) async -> ToolCallResult {
            ToolCallResult(content: "mock")
        }

        func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }

        func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }

        func toolCallResult(
            for toolCallID: String,
            conversationID: UUID,
            turnID: UUID?
        ) async -> ToolCallResult? { nil }

        func deleteToolCalls(for conversationID: UUID) async {}

        @MainActor
        private final class NoopHandle: ToolManagerObserverHandle, ToolJobObserverHandle {
            func cancel() {}
        }
    }

    /// 只提供自定义供应商 Store 的能力实现。
    @MainActor
    private final class MockStoreProviding: UserDefinedCloudProviderStoreProviding {
        let store: UserDefinedCloudProviderStore

        init(store: UserDefinedCloudProviderStore) {
            self.store = store
        }
    }

    // MARK: - Tests

    @Test("onBoot 注册工具与渲染器")
    func bootRegistersToolAndRenderer() throws {
        let kernel = KernelCoreContainer()
        let toolManager = MockToolManager()
        let rendering = DefaultToolCallRenderingProviding()
        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: nil)
        store.attach(manager: manager, apiService: VendorAPIService())

        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any ToolCallRenderingProviding).self, rendering)
        try kernel.registerProvider((any LLMManaging).self, manager)
        try kernel.registerProvider((any UserDefinedCloudProviderStoreProviding).self, MockStoreProviding(store: store))

        let plugin = PluginLLMProviderToolPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(toolManager.tool(named: AddLLMProviderTool.toolName) != nil)
        #expect(rendering.allRenderers.contains { type(of: $0).id == LLMProviderRowRenderer.id })
    }

    @Test("onShutdown 撤回工具与渲染器")
    func shutdownRemovesToolAndRenderer() throws {
        let kernel = KernelCoreContainer()
        let toolManager = MockToolManager()
        let rendering = DefaultToolCallRenderingProviding()

        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any ToolCallRenderingProviding).self, rendering)

        let plugin = PluginLLMProviderToolPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(toolManager.tool(named: AddLLMProviderTool.toolName) == nil)
        #expect(!rendering.allRenderers.contains { type(of: $0).id == LLMProviderRowRenderer.id })
    }

    @Test("缺少工具管理器时不崩溃")
    func bootWithoutToolManagerDoesNotCrash() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginLLMProviderToolPlugin()
        try plugin.onBoot(kernel: kernel)
    }

    @Test("插件启动顺序晚于供应商设置插件")
    func bootsAfterProviderSettingsPlugin() {
        // 自定义供应商 Store 由供应商设置插件注册，必须先于本插件就绪。
        #expect(PluginLLMProviderToolPlugin().order > 100)
    }
}
