import Foundation
import AgentToolKit
import HttpKit
import LLMKit
import SwiftUI
import Testing
@testable import LumiCoreKit

@Suite("LumiCoreKit 基础类型测试")
struct LumiCoreKitTests {

    @Test("ChatMessage 初始化与属性")
    func chatMessageInit() {
        let msg = ChatMessage(
            role: .user,
            conversationId: UUID(),
            content: "Hello"
        )
        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
        #expect(msg.isError == false)
        #expect(msg.toolCalls == nil)
        #expect(msg.shouldSendToLLM == true)
        #expect(msg.hasToolCalls == false)
    }

    @Test("ChatMessage 工具调用")
    func chatMessageWithToolCalls() {
        let toolCall = AgentToolKit.ToolCall(id: "tc_1", name: "read_file", arguments: "{\"path\": \"/tmp/test.txt\"}")
        let msg = ChatMessage(
            role: .assistant,
            conversationId: UUID(),
            content: "",
            toolCalls: [toolCall]
        )
        #expect(msg.hasToolCalls == true)
        #expect(msg.isToolOutput == false)
        #expect(msg.shouldSendToLLM == true)
    }

    @Test("ChatMessage 角色判断")
    func messageRoleSendableToLLM() {
        let cid = UUID()
        #expect(ChatMessage(role: .user, conversationId: cid, content: "").shouldSendToLLM == true)
        #expect(ChatMessage(role: .assistant, conversationId: cid, content: "").shouldSendToLLM == true)
        #expect(ChatMessage(role: .system, conversationId: cid, content: "").shouldSendToLLM == false)
        #expect(ChatMessage(role: .status, conversationId: cid, content: "").shouldSendToLLM == false)
        #expect(ChatMessage(role: .error, conversationId: cid, content: "").shouldSendToLLM == false)
    }

    @Test("PluginCategory 排序")
    func pluginCategorySortOrder() {
        #expect(PluginCategory.agent.sortOrder < PluginCategory.general.sortOrder)
        #expect(PluginCategory.editor.sortOrder < PluginCategory.theme.sortOrder)
    }

    @Test("SuperPlugin description supports language preference")
    func pluginDescriptionLanguagePreference() {
        #expect(LocalizedDescriptionPlugin.description == "English description")
        #expect(LocalizedDescriptionPlugin.description(for: .english) == "English description")
        #expect(LocalizedDescriptionPlugin.description(for: .chinese) == "中文描述")
        #expect(LanguagePreference(locale: Locale(identifier: "zh-Hans")).id == "zh")
        #expect(LanguagePreference(locale: Locale(identifier: "en-US")).id == "en")
    }

    @Test("StreamChunk 构造与属性")
    func streamChunkInit() {
        let chunk = StreamChunk(content: "Hi", isDone: false)
        #expect(chunk.content == "Hi")
        #expect(chunk.isDone == false)
        #expect(chunk.toolCalls == nil)

        let done = StreamChunk(isDone: true)
        #expect(done.isDone == true)
        #expect(done.content == nil)
    }

    @Test("StreamEventType 判断")
    func streamEventTypeChecks() {
        #expect(StreamEventType.thinkingDelta.isThinking() == true)
        #expect(StreamEventType.textDelta.isThinking() == false)
        #expect(StreamEventType.messageStop.isDone() == true)
        #expect(StreamEventType.ping.isReceivingContent() == true)
    }

    @Test("LLMModelSpec 与 LLMModelCapabilities")
    func modelSpecAndCapabilities() {
        let spec = LLMModelSpec(supportsVision: true, supportsTools: false)
        #expect(spec.capabilities.supportsVision == true)
        #expect(spec.capabilities.supportsTools == false)
        #expect(spec.contextWindowSize == nil)

        let specWithCtx = LLMModelSpec(contextWindowSize: 128000, supportsVision: false, supportsTools: true)
        #expect(specWithCtx.contextWindowSize == 128000)
    }

    @Test("SuperLLMProvider 默认模型目录处理重复模型 ID")
    func providerModelCatalogDeduplicatesModelIDs() {
        #expect(DuplicateModelProvider.availableModels == ["model-a", "model-b"])
        #expect(DuplicateModelProvider.modelSpecs["model-a"]?.contextWindowSize == 100)
        #expect(DuplicateModelProvider.modelCapabilities["model-a"]?.supportsTools == true)
        #expect(DuplicateModelProvider.modelDescriptions["model-a"] == "First model")
        #expect(DuplicateModelProvider.modelDescriptions["model-b"] == "Second model")
    }

    @Test("LocalModelInfo 初始化")
    func localModelInfo() {
        let info = LocalModelInfo(
            id: "qwen-7b",
            displayName: "Qwen 7B",
            size: "4.2 GB",
            minRAM: 8,
            expectedBytes: 4_500_000_000
        )
        #expect(info.id == "qwen-7b")
        #expect(info.supportsVision == false)
        #expect(info.supportsTools == true)
        #expect(info.series == nil)
    }

    @Test("AppConfig App Support 路径优先使用系统目录")
    func appConfigAppSupportDirectoryUsesSystemDirectory() {
        let appSupportURL = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)
        let homeDirectory = URL(fileURLWithPath: "/tmp/Home", isDirectory: true)

        let url = AppConfig.currentAppSupportDir(
            appSupportURL: appSupportURL,
            homeDirectory: homeDirectory,
            bundleID: "com.example.Lumi"
        )

        #expect(url.path == "/tmp/Application Support/com.example.Lumi")
    }

    @Test("AppConfig App Support 路径缺失时回退到用户目录")
    func appConfigAppSupportDirectoryFallsBackToHomeDirectory() {
        let homeDirectory = URL(fileURLWithPath: "/tmp/Home", isDirectory: true)

        let url = AppConfig.currentAppSupportDir(
            appSupportURL: nil,
            homeDirectory: homeDirectory,
            bundleID: nil
        )

        #expect(url.path == "/tmp/Home/Library/Application Support/com.coffic.Lumi")
    }

    @Test("RailItem Equatable")
    func railItemEquatable() {
        let item1 = RailItem(id: "tab1", title: "Tab 1", systemImage: "star", priority: 0) { AnyView(EmptyView()) }
        let item2 = RailItem(id: "tab1", title: "Tab 2", systemImage: "circle", priority: 1) { AnyView(EmptyView()) }
        let item3 = RailItem(id: "tab2", title: "Tab 1", systemImage: "star", priority: 0) { AnyView(EmptyView()) }
        #expect(item1 == item2) // same id
        #expect(item1 != item3) // different id
    }
}

private actor LocalizedDescriptionPlugin: SuperPlugin {
    static let policy: PluginPolicy = .disabled
    static let shared = LocalizedDescriptionPlugin()
    static let displayName = "Localized"
    static let description = "English description"
    static let iconName = "puzzlepiece"
    static var category: PluginCategory { .general }
    static var order: Int { 0 }

    static func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese: "中文描述"
        case .english: description
        }
    }
}

private struct DuplicateModelProvider: SuperLLMProvider {
    static let id = "duplicate-model-provider"
    static let displayName = "Duplicate Model Provider"
    static let shortName = "DMP"
    static let description = "Provider with repeated model IDs"
    static let apiKeyStorageKey = "DuplicateModelProviderAPIKey"
    static let defaultModel = "model-a"
    static let modelCatalog = [
        LLMModelCatalogItem(
            id: "model-a",
            description: "First model",
            spec: LLMModelSpec(contextWindowSize: 100, supportsVision: false, supportsTools: true)
        ),
        LLMModelCatalogItem(
            id: "model-a",
            description: "Duplicate model",
            spec: LLMModelSpec(contextWindowSize: 200, supportsVision: true, supportsTools: false)
        ),
        LLMModelCatalogItem(
            id: "model-b",
            description: "Second model",
            spec: LLMModelSpec(contextWindowSize: 300, supportsVision: true, supportsTools: true)
        )
    ]

    let baseURL = "https://example.invalid"

    init() {}

    func buildRequest(url: URL) -> URLRequest {
        URLRequest(url: url)
    }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        [:]
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        ("", nil)
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        nil
    }

    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        [:]
    }


    func streamChat(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        try await RemoteLLMProviderTransport.streamChat(
            provider: self,
            messages: messages,
            config: config,
            tools: tools,
            maxThinkingLength: maxThinkingLength,
            onChunk: onChunk,
            onRequestStart: onRequestStart
        )
    }

    func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        try await RemoteLLMProviderTransport.sendMessage(
            provider: self,
            messages: messages,
            config: config,
            tools: tools
        )
    }

    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .apiKeyOnly
    }
}

// MARK: - MainActor 隔离测试

@Suite("LumiCoreKit MainActor 隔离测试")
@MainActor
struct LumiCoreKitActorTests {

    @Test("SendMessageContext 基本操作")
    func sendMessageContext() async {
        let msg = ChatMessage(role: .user, conversationId: UUID(), content: "test")
        let ctx = SendMessageContext(
            conversationId: msg.conversationId,
            message: msg
        )
        #expect(ctx.transientSystemPrompts.isEmpty)

        ctx.transientSystemPrompts.append("You are helpful")
        #expect(ctx.transientSystemPrompts.count == 1)
    }

    @Test("AppLLMVM direct state changes propagate through setters")
    func appLLMVMDirectStateChangesPropagateThroughSetters() {
        var selectedProviderIds: [String] = []
        var currentModels: [String] = []
        var autoModeValues: [Bool] = []

        let llmVM = AppLLMVM(
            selectedProviderIdSetter: { selectedProviderIds.append($0) },
            currentModelSetter: { currentModels.append($0) },
            isAutoModeSetter: { autoModeValues.append($0) }
        )

        llmVM.selectedProviderId = "openai"
        llmVM.currentModel = "gpt-4o"
        llmVM.isAutoMode = true
        llmVM.isAutoMode = false

        #expect(selectedProviderIds == ["openai"])
        #expect(currentModels == ["gpt-4o"])
        #expect(autoModeValues == [true, false])
    }

    @Test("AppLLMVM host state sync updates values without echoing through setters")
    func appLLMVMHostStateSyncDoesNotEchoThroughSetters() {
        var selectedProviderIds: [String] = []
        var currentModels: [String] = []
        var autoModeValues: [Bool] = []

        let llmVM = AppLLMVM(
            selectedProviderId: "anthropic",
            currentModel: "claude",
            isAutoMode: true,
            selectedProviderIdSetter: { selectedProviderIds.append($0) },
            currentModelSetter: { currentModels.append($0) },
            isAutoModeSetter: { autoModeValues.append($0) }
        )

        llmVM.updateSelectedProviderIdFromHost("openai")
        llmVM.updateCurrentModelFromHost("gpt-4o")
        llmVM.updateIsAutoModeFromHost(false)
        llmVM.updateLastAutoRouteSummaryFromHost("routed")

        #expect(llmVM.selectedProviderId == "openai")
        #expect(llmVM.currentModel == "gpt-4o")
        #expect(llmVM.isAutoMode == false)
        #expect(llmVM.lastAutoRouteSummary == "routed")
        #expect(selectedProviderIds.isEmpty)
        #expect(currentModels.isEmpty)
        #expect(autoModeValues.isEmpty)
    }

    @Test("旧版菜单栏弹窗入口仍会聚合为数组")
    func legacyMenuBarPopupViewFallback() {
        let views = LegacyMenuBarPopupPlugin.shared.addMenuBarPopupViews()

        #expect(views.count == 1)
    }

    @Test("SendPipeline 中间件排序与执行")
    func sendPipelineOrdering() async {
        let executionOrder = LockedArray<String>()

        let m1 = PipelineTestMiddleware(id: "m1", order: 2, executionOrder: executionOrder)
        let m2 = PipelineTestMiddleware(id: "m2", order: 1, executionOrder: executionOrder)

        let pipeline = SendPipeline(middlewares: [m1, m2])
        let msg = ChatMessage(role: .user, conversationId: UUID(), content: "hi")
        let ctx = SendMessageContext(conversationId: msg.conversationId, message: msg)

        await pipeline.run(ctx: ctx) { _ in }

        let order = executionOrder.all
        #expect(order.count == 2)
        #expect(order[0] == "m2") // order=1 先执行
        #expect(order[1] == "m1") // order=2 后执行
    }

    @Test("OrderedMiddlewarePipeline 支持自定义 Context")
    func orderedMiddlewarePipelineCustomContext() async {
        let executionOrder = LockedArray<String>()
        let ctx = PipelineProbeContext()

        let pipeline = OrderedMiddlewarePipeline<PipelineProbeContext, String>(
            middlewares: [
                AnyOrderedMiddleware(
                    id: "late",
                    order: 2,
                    handle: { ctx, next in
                        executionOrder.append("pre-late")
                        ctx.value += "B"
                        await next(ctx)
                    },
                    handlePost: { _, response in
                        executionOrder.append("post-late-\(response)")
                    }
                ),
                AnyOrderedMiddleware(
                    id: "early",
                    order: 1,
                    handle: { ctx, next in
                        executionOrder.append("pre-early")
                        ctx.value += "A"
                        await next(ctx)
                    },
                    handlePost: { _, response in
                        executionOrder.append("post-early-\(response)")
                    }
                ),
            ]
        )

        await pipeline.run(ctx: ctx) { ctx in
            executionOrder.append("terminal-\(ctx.value)")
        }
        await pipeline.runPost(metadata: makeMetadata(), response: "ok")

        #expect(executionOrder.all == [
            "pre-early",
            "pre-late",
            "terminal-AB",
            "post-early-ok",
            "post-late-ok",
        ])
    }
}

private actor LegacyMenuBarPopupPlugin: SuperPlugin {
    static let shared = LegacyMenuBarPopupPlugin()
    static let policy: PluginPolicy = .disabled
    static let displayName = "Legacy Menu"
    static let description = "Legacy menu popup"
    static let iconName = "menubar.rectangle"
    static var category: PluginCategory { .general }
    static var order: Int { 0 }

    @MainActor
    func addMenuBarPopupView() -> AnyView? {
        AnyView(Text("Legacy"))
    }
}

// MARK: - Test Helpers

/// 线程安全的数组（用于测试中记录执行顺序）
final class LockedArray<T>: @unchecked Sendable {
    private var _value: [T] = []
    private let lock = NSLock()

    var all: [T] {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func append(_ element: T) {
        lock.lock()
        _value.append(element)
        lock.unlock()
    }
}

/// 测试用中间件
@MainActor
struct PipelineTestMiddleware: SuperSendMiddleware {
    let id: String
    let order: Int
    let executionOrder: LockedArray<String>

    func handle(ctx: SendMessageContext, next: @escaping @MainActor (SendMessageContext) async -> Void) async {
        executionOrder.append(id)
        await next(ctx)
    }
}

@MainActor
final class PipelineProbeContext {
    var value = ""
}

private func makeMetadata() -> HTTPRequestMetadata {
    HTTPRequestMetadata(
        requestId: UUID(),
        method: "POST",
        url: "https://example.com",
        requestHeaders: [:],
        requestBodySizeBytes: 0,
        requestBodyPreview: nil,
        sentAt: Date()
    )
}
