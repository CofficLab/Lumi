import Foundation
@testable import LumiCoreKit
import Testing

// MARK: - LumiCore 新 API 单元测试
//
// 覆盖 LumiCore 从 enum（单例）迁移到 final class（可实例化）后引入的新 API：
// - 协议层（LumiCoreAccessing / LumiCoreBootstrapping）
// - 实例化与多实例隔离
// - ServiceRegistry（registerService / resolveService）
// - makePluginContext 自动注入基础服务 + 外部注入
// - configure 同步设置 dataRootDirectory（保证协议契约一致）
//
// 这些测试覆盖「LumiCore 迁移任务6」+「新 API 单元测试任务7」。

// MARK: - Init / Multi-instance Isolation

@MainActor
@Test func lumiCoreInitCreatesIndependentEmptyInstance() {
    let core = LumiCore()

    // 初始状态：所有可选属性为 nil（没有依赖任何服务即可构造）
    #expect(core.dataRootDirectory == nil)
    #expect(core.projectState == nil)
    #expect(core.layoutState == nil)
    #expect(core.chatService == nil)
    #expect(core.editorService == nil)

    // logoRegistry 总是指向全局共享实例
    #expect(core.logoRegistry === LogoRegistry.shared)
}

@MainActor
@Test func lumiCoreInstancesDoNotShareState() throws {
    let tempRootA = FileManager.default.temporaryDirectory
        .appendingPathComponent("InstanceA-\(UUID().uuidString)", isDirectory: true)
    let tempRootB = FileManager.default.temporaryDirectory
        .appendingPathComponent("InstanceB-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRootA)
        try? FileManager.default.removeItem(at: tempRootB)
    }

    let dataRootA = tempRootA.appendingPathComponent("db", isDirectory: true)
    let dataRootB = tempRootB.appendingPathComponent("db", isDirectory: true)

    let coreA = LumiCore()
    let coreB = LumiCore()

    // 两个实例各自配置独立的数据根目录
    try coreA.configure(dataRootDirectory: dataRootA)
    try coreB.configure(dataRootDirectory: dataRootB)

    // 独立之前：projectState/layoutState 在 boot() 之前为 nil（这是预期设计）
    #expect(coreA.projectState == nil)
    #expect(coreB.projectState == nil)

    // 数据根目录独立
    #expect(coreA.dataRootDirectory?.standardizedFileURL == dataRootA.standardizedFileURL)
    #expect(coreB.dataRootDirectory?.standardizedFileURL == dataRootB.standardizedFileURL)

    // 一个实例修改不影响另一个
    final class TestService {}
    coreA.registerService(TestService.self, TestService())
    #expect(coreA.resolveService(TestService.self) != nil)
    #expect(coreB.resolveService(TestService.self) == nil)
}

// MARK: - configure

@MainActor
@Test func lumiCoreConfigureSetsDataRootDirectoryAndCreatesPhysicalDirectory() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("Configure-\(UUID().uuidString)", isDirectory: true)
    let dataRoot = tempRoot.appendingPathComponent("db_debug_v4", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let core = LumiCore()

    // configure 之前 dataRootDirectory 为 nil
    #expect(core.dataRootDirectory == nil)

    try core.configure(dataRootDirectory: dataRoot)

    // configure 之后 dataRootDirectory 非 nil（协议契约）
    #expect(core.dataRootDirectory?.standardizedFileURL == dataRoot.standardizedFileURL)

    // 物理目录已创建
    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: dataRoot.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
}

@MainActor
@Test func lumiCoreConfigureCreatesNestedDirectories() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConfigureNested-\(UUID().uuidString)/a/b/c", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(
            at: tempRoot.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        )
    }

    let core = LumiCore()
    try core.configure(dataRootDirectory: tempRoot)

    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: tempRoot.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
}

// MARK: - Service Registry

@MainActor
@Test func lumiCoreRegisterAndResolveServiceByType() {
    final class Tag {}

    let core = LumiCore()

    // 未注册时 resolve 返回 nil
    #expect(core.resolveService(Tag.self) == nil)

    let service = Tag()
    core.registerService(Tag.self, service)

    // 注册后 resolve 返回同一实例
    #expect(core.resolveService(Tag.self) === service)
}

@MainActor
@Test func lumiCoreRegisterServiceAllowsOverride() {
    final class Tag {}

    let core = LumiCore()
    let first = Tag()
    let second = Tag()

    core.registerService(Tag.self, first)
    #expect(core.resolveService(Tag.self) === first)

    // 同一类型可以重复注册——后注册覆盖前者
    core.registerService(Tag.self, second)
    #expect(core.resolveService(Tag.self) === second)
}

@MainActor
@Test func lumiCoreRegisterServiceIsolatedAcrossInstances() {
    final class Tag {}

    let coreA = LumiCore()
    let coreB = LumiCore()

    coreA.registerService(Tag.self, Tag())
    #expect(coreA.resolveService(Tag.self) != nil)
    #expect(coreB.resolveService(Tag.self) == nil)
}

@MainActor
@Test func lumiCoreResolveServiceByProtocolExistential() {
    let core = LumiCore()

    // 注册一个 LumiChatServicing 协议实现
    let mock = MockChatServicing()
    core.registerService((any LumiChatServicing).self, mock)

    // 通过协议存在类型解析
    let resolved = core.resolveService((any LumiChatServicing).self)
    #expect(resolved === mock)
}

// MARK: - LumiCoreAccessing 协议访问

@MainActor
@Test func lumiCoreConformsToLumiCoreAccessingProtocol() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("Protocol-\(UUID().uuidString)", isDirectory: true)
    let dataRoot = tempRoot.appendingPathComponent("db_debug_v4", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let core = LumiCore()
    try core.configure(dataRootDirectory: dataRoot)

    // 通过协议存在类型访问核心状态
    let accessor: any LumiCoreAccessing = core
    #expect(accessor.dataRootDirectory?.standardizedFileURL == dataRoot.standardizedFileURL)
    #expect(accessor.logoRegistry === LogoRegistry.shared)
    #expect(accessor.projectState == nil)
    #expect(accessor.layoutState == nil)
    #expect(accessor.chatService == nil)
    #expect(accessor.editorService == nil)
}

@MainActor
@Test func lumiCoreMakePluginContextViaProtocol() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProtocolCtx-\(UUID().uuidString)", isDirectory: true)
    let dataRoot = tempRoot.appendingPathComponent("db_debug_v4", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let core = LumiCore()
    try core.configure(dataRootDirectory: dataRoot)

    let accessor: any LumiCoreAccessing = core
    let context = accessor.makePluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .narrow,
        showsRail: true,
        showsPanelChrome: false,
        isChatSectionVisible: true,
        additionalDependencies: { _ in }
    )

    #expect(context.activeSectionID == "chat")
    #expect(context.activeSectionTitle == "Chat")
    #expect(context.chatSection == .narrow)
    #expect(context.showsRail)
    #expect(!context.showsPanelChrome)
    #expect(context.showsChatSection)
    #expect(context.lumiCore === accessor)
}

@MainActor
@Test func lumiCoreAccessingProtocolHidesBootstrapMethods() throws {
    // 类型层面的契约验证：协议不存在 boot/reset 方法。
    // 这保护插件代码不能误用启动期 API（编译期验证即可）。
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("Accessing-\(UUID().uuidString)", isDirectory: true)
    let dataRoot = tempRoot.appendingPathComponent("db", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let core = LumiCore()
    try core.configure(dataRootDirectory: dataRoot)

    let accessor: any LumiCoreAccessing = core

    // 编译期保证：accessor 不暴露 registerService/resolveService/setupChatService
    // （这条测试更多是为了文档化——编译器拒绝这里的 boot 调用，因为 boot 在 LumiCoreBootstrapping 上）
    // 我们只验证 accessor 能拿到 storage helper
    let pluginDir = accessor.pluginDataDirectory(for: "Test")
    #expect(pluginDir.deletingLastPathComponent().standardizedFileURL == dataRoot.standardizedFileURL)
}

// MARK: - LumiCoreBootstrapping 协议访问

@MainActor
@Test func lumiCoreConformsToLumiCoreBootstrappingProtocol() {
    let core = LumiCore()
    let bootstrapper: any LumiCoreBootstrapping = core

    // 调用 registerService 协议方法——这是 LumiCoreBootstrapping 的合约之一
    final class BootTag {}
    bootstrapper.registerService(BootTag.self, BootTag())
    #expect(bootstrapper.resolveService(BootTag.self) != nil)
}

@MainActor
@Test func lumiCoreBootstrappingProtocolProvidesChatServiceFactory() {
    let core = LumiCore()
    let bootstrapper: any LumiCoreBootstrapping = core

    // 注册工厂；不触发 boot 也不应执行工厂闭包
    var callCount = 0
    bootstrapper.setupChatService { _ in
        callCount += 1
        return MockChatServicing()
    }
    #expect(callCount == 0)  // setupChatService 只保存工厂，不立即调用
}

// MARK: - makePluginContext 自动注入

@MainActor
@Test func lumiCoreMakePluginContextAutoInjectsRegisteredServices() {
    let core = LumiCore()

    // 注册一个 LumiChatServicing 实现
    let mock = MockChatServicing()
    core.registerService((any LumiChatServicing).self, mock)

    // 调用 makePluginContext 应自动注入
    let context = core.makePluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat"
    )

    // 通过 context.resolve 应能拿到刚才注册的实例
    #expect(context.resolve((any LumiChatServicing).self) === mock)
}

@MainActor
@Test func lumiCoreMakePluginContextExposesLumiCoreItself() {
    let core = LumiCore()
    let context = core.makePluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat"
    )

    // 插件可从 context 拿到 LumiCore 引用
    #expect(context.lumiCore === core)
}

@MainActor
@Test func lumiCoreMakePluginContextMergesExternalDependencies() {
    let core = LumiCore()

    final class ExternalService {}

    let context = core.makePluginContext(
        activeSectionID: "editor",
        activeSectionTitle: "Editor",
        additionalDependencies: { dependencies in
            dependencies.register(ExternalService.self, ExternalService())
        }
    )

    // 通过 additionalDependencies 注入的也能 resolve 到
    #expect(context.resolve(ExternalService.self) != nil)
}

@MainActor
@Test func lumiCoreMakePluginContextDefaultsAreReasonable() {
    let core = LumiCore()
    let context = core.makePluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat"
    )

    // 默认参数：chatSection = .none、showsRail/showPanelChrome = false
    #expect(context.chatSection == .none)
    #expect(!context.showsRail)
    #expect(!context.showsPanelChrome)
    // chatSection 不显示时 isChatSectionVisible 默认从 chatSection.isVisible 推导
    #expect(!context.showsChatSection)
}

// MARK: - Helpers

/// 轻量级 `LumiChatServicing` mock，专门用于「满足协议、暴露身份」测试。
/// 只实现协议的最少必要字段——很多字段根本不会触发。
private final class MockChatServicing: LumiChatServicing, @unchecked Sendable {
    // MARK: - Required computed properties（实现协议即可，默认空状态）

    var conversations: [LumiConversationSummary] = []
    var selectedConversationID: UUID?
    var providerInfos: [LumiLLMProviderInfo] = []
    var selectedProviderID: String?
    var selectedModel: String?
    var messageRenderers: [LumiMessageRendererItem] = []
    var revision: Int = 0
    var agentTools: [any LumiAgentTool] = []
    var pendingMessages: [LumiPendingMessage] = []
    var routingMode: LumiModelRoutingMode = .manual
    var pendingToolConfirmation: LumiPendingToolConfirmation?

    // MARK: - Required methods（占位实现，绝不会被调用）

    func isSending(for conversationID: UUID?) -> Bool { false }
    @discardableResult func createConversation(title: String?) -> UUID { UUID() }
    @discardableResult
    func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID { UUID() }
    func selectConversation(id: UUID) {}
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    @discardableResult
    func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { false }
    func selectProvider(id: String, model: String?) {}
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func provider(forID id: String) -> (any LumiLLMProvider)? { nil }
    func setRoutingMode(_ mode: LumiModelRoutingMode) {}
    func language(for conversationID: UUID?) -> LumiConversationLanguage { .english }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    func registerToolService(_ toolService: (any LumiToolServicing)?) {}
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
    func messages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { [] }
    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool { false }
    func enqueueText(_ text: String, in conversationID: UUID?) {}
    func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {}
    func continueTurn(in conversationID: UUID) {}
    func cancelSending(for conversationID: UUID?) {}
    func approvePendingTool() {}
    func rejectPendingTool() {}
    func removePendingMessage(id: UUID) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func resendMessage(id: UUID, in conversationID: UUID) async {}
    func send(_ text: String, in conversationID: UUID?) async {}
    func generateEphemeralCompletion(messages: [LumiChatMessage], model: String, conversationID: UUID) async throws -> LumiChatMessage {
        throw NSError(domain: "test", code: 0)
    }
    func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
        .init(currentTokens: 0, limit: 0)
    }
}
