import LumiComponentLayout

public struct LumiPluginDependencies {
    private var values: [ObjectIdentifier: Any]

    public init() {
        self.values = [:]
    }

    public init(_ configure: (inout LumiPluginDependencies) -> Void) {
        self.init()
        configure(&self)
    }

    public mutating func register<T>(_ type: T.Type, _ value: T) {
        values[ObjectIdentifier(type)] = value
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T? {
        values[ObjectIdentifier(type)] as? T
    }
}

public struct LumiPluginContext {
    public let activeSectionID: String
    public let activeSectionTitle: String
    public let chatSection: LumiChatSectionLayout
    public let showsRail: Bool
    public let showsPanelChrome: Bool
    /// Whether the chat section is currently rendered in the app layout.
    public let isChatSectionVisible: Bool
    public let dependencies: LumiPluginDependencies
    /// 可选的 LumiCore 实例，供插件访问核心服务
    public let lumiCore: (any LumiCoreAccessing)?

    /// Whether the active view container is configured to host a chat section.
    public var supportsChatSection: Bool {
        chatSection.isVisible
    }

    /// Whether chat section contributions should be active for this context.
    public var showsChatSection: Bool {
        isChatSectionVisible
    }

    /// Current active LLM provider ID (conversation preference with global fallback).
    @MainActor
    public var activeProviderID: String? {
        Self.resolveActiveProviderID(from: dependencies)
    }

    /// 当前打开的项目（若存在）。等价于 `lumiCore?.projectComponent.currentProject`。
    ///
    /// per-request 动态注入改造后，插件在 `agentTools(context:)` 内据此判断要不要
    /// 返回工具（例如只在 Swift 项目下暴露 Swift 工具）。每次发消息时由
    /// `buildToolSet` 用最新的 `makePluginContext` 构造，反映此刻的当前项目。
    @MainActor
    public var currentProject: ProjectEntry? {
        lumiCore?.projectComponent.currentProject
    }

    public init(
        activeSectionID: String,
        activeSectionTitle: String,
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        isChatSectionVisible: Bool? = nil,
        dependencies: LumiPluginDependencies = LumiPluginDependencies(),
        lumiCore: (any LumiCoreAccessing)? = nil
    ) {
        self.activeSectionID = activeSectionID
        self.activeSectionTitle = activeSectionTitle
        self.chatSection = chatSection
        self.showsRail = showsRail
        self.showsPanelChrome = showsPanelChrome
        self.isChatSectionVisible = isChatSectionVisible ?? chatSection.isVisible
        self.dependencies = dependencies
        self.lumiCore = lumiCore
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T? {
        dependencies.resolve(type)
    }

    public func withAdditionalDependencies(
        _ configure: (inout LumiPluginDependencies) -> Void
    ) -> LumiPluginContext {
        var dependencies = self.dependencies
        configure(&dependencies)
        return LumiPluginContext(
            activeSectionID: activeSectionID,
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            dependencies: dependencies,
            lumiCore: lumiCore
        )
    }

    @MainActor
    public static func resolveActiveProviderID(from dependencies: LumiPluginDependencies) -> String? {
        guard let chatService = dependencies.resolve(LumiChatServicing.self) else {
            return nil
        }
        return chatService.providerID(for: chatService.selectedConversationID)
    }
}
