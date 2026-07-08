import Combine
import Foundation
import SwiftUI

@MainActor
public enum LumiCore {
    private static var configuration: LumiCoreConfiguration?

    /// Logo 注册表
    @MainActor public static let logoRegistry = LogoRegistry()

    /// 项目状态管理器
    @MainActor public static private(set) var projectState: LumiProjectState?

    /// 布局状态管理器
    @MainActor public static private(set) var layoutState: LumiLayoutState?

    /// 聊天服务（由外部通过 `setupChatService` 工厂创建，自动注册到服务表）
    @MainActor public static private(set) var chatService: (any LumiChatServicing)?

    /// ChatService 工厂闭包类型
    public typealias ChatServiceFactory = @MainActor (URL) -> any LumiChatServicing

    /// ChatService 工厂，由 LumiApp 在启动时提供。
    /// 提供后，LumiCore 在 boot() 时自动创建并注册到服务表。
    private static var chatServiceFactory: ChatServiceFactory?

    /// 设置 ChatService 工厂。
    /// - Parameters:
    ///   - factory: 工厂闭包，接收数据库目录参数，返回 ChatService 实例。
    ///   - 应在 `LumiCore.boot()` 之前调用。
    public static func setupChatService(_ factory: @escaping ChatServiceFactory) {
        chatServiceFactory = factory
    }

    /// 编辑器服务（由外部通过 `setupEditorBootstrap` 工厂创建，自动注册到服务表）。
    /// 使用 `AbstractEditorServicing` 抽象协议，避免 LumiCoreKit 反向依赖 EditorService（会成环）。
    @MainActor public static private(set) var editorService: (any AbstractEditorServicing)?

    /// EditorBootstrap 工厂闭包类型。
    /// 返回抽象的 `AbstractEditorServicing`，具体 `LumiEditorServicing` 由 LumiApp 自行注册。
    public typealias EditorBootstrapFactory = @MainActor () -> any AbstractEditorServicing

    /// EditorBootstrap 工厂，由 LumiApp 在启动时提供。
    /// 提供后，调用 `bootstrapEditor()` 时自动创建并注册到服务表。
    /// 注意：与 ChatService 不同，此工厂**不在** `boot()` 中调用，因为编辑器启动依赖
    /// `PluginService`（启用态过滤），而后者在 LumiCore.boot() 之后才构造完成。
    private static var editorBootstrapFactory: EditorBootstrapFactory?

    /// 设置 EditorBootstrap 工厂。
    /// - Parameter factory: 工厂闭包，返回编辑器服务实例（遵循 `AbstractEditorServicing`）。
    ///   应在依赖（如 PluginService）就绪后调用 `bootstrapEditor()`。
    public static func setupEditorBootstrap(_ factory: @escaping EditorBootstrapFactory) {
        editorBootstrapFactory = factory
    }

    /// 启动编辑器服务。
    /// 调用工厂创建实例、存入 `editorService` 并注册到服务表。
    /// 应在 `setupEditorBootstrap` 之后、且其依赖（如 PluginService）就绪时调用。
    @MainActor
    public static func bootstrapEditor() {
        guard let factory = editorBootstrapFactory else { return }
        let service = factory()
        editorService = service
        registerService((any AbstractEditorServicing).self, service)
        // 清空工厂，避免重复 bootstrap
        editorBootstrapFactory = nil
    }

    // MARK: - Service Registry

    /// 内部服务注册表，用于 `makePluginContext` 自动注入依赖。
    @MainActor private static var services: [ObjectIdentifier: Any] = [:]

    /// 注册一个服务实例，供 `LumiCore.makePluginContext` 自动注入。
    /// - 应在 `RootContainer` 初始化完成后调用一次。
    public static func registerService<T>(_ type: T.Type, _ instance: T) {
        services[ObjectIdentifier(type)] = instance
    }

    /// 从注册表解析已注册的服务实例。
    public static func resolveService<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    // MARK: - Plugin Context Factory

    /// 统一创建 `LumiPluginContext`。
    /// 外部服务（如 EditorService、LumiChatServicing 等）需要通过 `additionalDependencies` 手动注入。
    /// - Parameters:
    ///   - activeSectionID: 当前活跃区域 ID。
    ///   - activeSectionTitle: 当前活跃区域标题。
    ///   - chatSection: 聊天区布局配置。
    ///   - showsRail: 是否显示侧边栏。
    ///   - showsPanelChrome: 是否显示面板边框。
    ///   - isChatSectionVisible: 聊天区是否可见。
    ///   - additionalDependencies: 依赖注册回调，用于注入外部服务。
    /// - Returns: 初始化完成的 `LumiPluginContext`。
    public static func makePluginContext(
        activeSectionID: String,
        activeSectionTitle: String,
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        isChatSectionVisible: Bool? = nil,
        additionalDependencies: (inout LumiPluginDependencies) -> Void = { _ in }
    ) -> LumiPluginContext {
        var dependencies = LumiPluginDependencies()

        // 基础服务自动注入（仅 LumiCoreKit 内部定义的服务）
        if let chat = resolveService((any LumiChatServicing).self) {
            dependencies.register((any LumiChatServicing).self, chat)
        }
        if let history = resolveService((any HistoryQueryService).self) {
            dependencies.register((any HistoryQueryService).self, history)
        }
        if let presenter = resolveService(LumiBottomPanelLayoutPresenting.self) {
            dependencies.register(LumiBottomPanelLayoutPresenting.self, presenter)
        }
        if let providerSettings = resolveService((any LumiLLMProviderSettingsContributing).self) {
            dependencies.register((any LumiLLMProviderSettingsContributing).self, providerSettings)
        }

        // 外部服务由调用者手动注入
        additionalDependencies(&dependencies)

        return LumiPluginContext(
            activeSectionID: activeSectionID,
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            dependencies: dependencies
        )
    }

    // MARK: - 启动

    /// 启动 LumiCore
    /// 初始化所有核心模块
    public static func boot(databaseDirectory: URL? = nil) {
        projectState = LumiProjectState()
        layoutState = LumiLayoutState()

        // 自动创建并注册 ChatService
        if let databaseDirectory, let factory = chatServiceFactory {
            chatService = factory(databaseDirectory)
            registerService((any LumiChatServicing).self, chatService!)
            // ChatService 通常也实现 HistoryQueryService
            if let history = chatService as? any HistoryQueryService {
                registerService((any HistoryQueryService).self, history)
            }
        }
    }

    // MARK: - 配置

    public static func configure(dataRootDirectory: URL) {
        let directory = dataRootDirectory.standardizedFileURL
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        configuration = LumiCoreConfiguration(dataRootDirectory: directory)
    }

    public static var dataRootDirectory: URL {
        guard let configuration else {
            fatalError("LumiCore.configure(dataRootDirectory:) must be called before using LumiCore storage APIs.")
        }

        return configuration.dataRootDirectory
    }

    public static var coreDataDirectory: URL {
        directory(named: "Core", under: dataRootDirectory)
    }

    public static func pluginDataDirectory(for pluginName: String) -> URL {
        directory(named: sanitizeDirectoryName(pluginName, fallback: "Plugin"), under: dataRootDirectory)
    }

    private static func directory(named name: String, under root: URL) -> URL {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }

    private static func sanitizeDirectoryName(_ name: String, fallback: String) -> String {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return sanitized.isEmpty ? fallback : sanitized
    }
}
