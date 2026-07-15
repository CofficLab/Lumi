import Foundation
import SwiftUI

// MARK: - LumiCoreAccessing

/// 视图与插件访问 LumiCore 核心状态的协议。
///
/// 该协议暴露**只读**且**频繁使用**的 API，供 SwiftUI 视图（App + 插件）通过
/// `@Environment(\.lumiCore)` 安全获取。它刻意不暴露任何修改内部状态的能力，
/// 以保证视图层无法污染内核状态。
///
/// 启动期的一次性配置（`boot`、`registerService`、`setupChatService` 等）请使用
/// `LumiCoreBootstrapping` 协议。
///
/// - Important: 实现必须为 class（`AnyObject`），因为协议内含可变状态；
///
/// 自 LumiCore 迁移到 `final class` 后,`LumiCoreAccessing` 继承 `ObservableObject`,
/// 允许 SwiftUI 视图通过 `@EnvironmentObject` 完整观察内核状态变化。
///   所有访问必须在主线程（`@MainActor`）。
@MainActor
public protocol LumiCoreAccessing: AnyObject, ObservableObject {
    // MARK: - State

    /// 数据根目录（`boot` 后非空）。
    var dataRootDirectory: URL? { get }

    /// Logo 注册表（指向全局共享的 `LogoRegistry.shared`）。
    var logoRegistry: LogoRegistry { get }

    /// 项目状态管理器（`boot` 后非空）。
    var projectState: LumiProjectState? { get }

    /// 布局状态管理器（`boot` 后非空）。
    var layoutState: LumiLayoutState? { get }

    /// 聊天服务（`boot` 时由 `ChatServiceFactory` 创建并自动注册）。
    var chatService: (any LumiChatServicing)? { get }

    /// 编辑器服务（`boot(editorFactory:)` 时由工厂创建）。
    var editorService: (any AbstractEditorServicing)? { get }

    // MARK: - Storage

    /// 核心数据目录（`dataRootDirectory/Core`）。
    var coreDataDirectory: URL { get }

    /// 插件专属数据目录（`dataRootDirectory/<PluginName>`，自动创建）。
    /// - Parameter pluginName: 插件名称。
    /// - Returns: 插件专属的数据目录路径。
    func pluginDataDirectory(for pluginName: String) -> URL

    // MARK: - Plugin Context Factory

    /// 统一创建 `LumiPluginContext`。
    ///
    /// 基础服务（如 `LumiChatServicing`、`LumiToolServicing` 等）由 LumiCore 自动注入；
    /// App 层自定义服务可通过 `additionalDependencies` 手动注入。
    ///
    /// - Parameters:
    ///   - activeSectionID: 当前活跃区域 ID。
    ///   - activeSectionTitle: 当前活跃区域标题。
    ///   - chatSection: 聊天区布局配置。
    ///   - showsRail: 是否显示侧边栏。
    ///   - showsPanelChrome: 是否显示面板边框。
    ///   - isChatSectionVisible: 聊天区是否可见。
    ///   - additionalDependencies: 依赖注册回调，用于注入外部服务。
    /// - Returns: 初始化完成的 `LumiPluginContext`。
    func makePluginContext(
        activeSectionID: String,
        activeSectionTitle: String,
        chatSection: LumiChatSectionLayout,
        showsRail: Bool,
        showsPanelChrome: Bool,
        isChatSectionVisible: Bool?,
        additionalDependencies: (inout LumiPluginDependencies) -> Void
    ) -> LumiPluginContext
}

// MARK: - LumiCoreBootstrapping

/// LumiCore 启动期配置协议。
///
/// 该协议暴露**仅应在 App 启动时调用一次**的 API（注册服务、启动工具服务、boot 等）。
/// 把它从 `LumiCoreAccessing` 独立出来的原因：
///
/// 1. **协议隔离**：视图层不需要也不应该接触这些能力，避免被误调用。
/// 2. **测试友好**：单测时 mock `LumiCoreAccessing` 不需要实现启动期逻辑。
/// 3. **编译期保护**：插件如果不小心调用了 boot 类 API，编译器会直接报错。
///
/// - Important: 仅 `LumiCore` 主类（及其子类）在 App 启动期实现并使用该协议。
@MainActor
public protocol LumiCoreBootstrapping: AnyObject {
    // MARK: - ChatService Factory

    /// ChatService 工厂闭包类型。
    typealias ChatServiceFactory = @MainActor (URL) -> any LumiChatServicing

    /// EditorBootstrap 工厂闭包类型。
    typealias EditorBootstrapFactory<Service: AbstractEditorServicing> =
        @MainActor (any LumiAgentToolProviding) throws -> Service

    /// 设置 ChatService 工厂。
    /// - Parameter factory: 工厂闭包，接收数据库目录参数，返回 ChatService 实例。
    ///   应在 `boot()` 之前调用。
    func setupChatService(_ factory: @escaping ChatServiceFactory)

    // MARK: - Service Registry

    /// 注册一个服务实例，供 `makePluginContext` 自动注入。
    /// 应在 `RootContainer` 初始化完成后调用一次。
    func registerService<T>(_ type: T.Type, _ instance: T)

    /// 从注册表解析已注册的服务实例。
    func resolveService<T>(_ type: T.Type) -> T?

    // MARK: - Tool Service

    /// 启动 `ToolService` 并注入运行环境。
    ///
    /// `builtInTools` 是运行期会由 `bootstrapToolContributions` 注入 `ToolService` 的
    /// 内置工具（如 `ChatService.builtInTools`）。把它们传入启动期校验，让 boot 阶段
    /// 就能拦截跨来源的命名冲突。
    func bootstrapToolService(
        provider: any LumiAgentToolProviding,
        builtInTools: [any LumiAgentTool]
    ) throws

    /// 编排 Agent Tool 工具的注册与注入。
    ///
    /// 把 `provider` 提供的插件工具、内置工具和子 Agent 工具注册到 `ToolService`，
    /// 并把 `ToolService` 关联到 `ChatService`。App 层无需直接接触 `ToolService`、
    /// `LumiAgentTool` 或 `SubAgentDelegateTool` 任何细节。
    func bootstrapToolContributions(
        provider: any LumiAgentToolProviding,
        context: LumiPluginContext,
        builtInTools: [any LumiAgentTool]
    )

    /// 启动期工具名校验：让 boot 阶段就能拦截插件侧的配置冲突。
    ///
    /// 校验的是 `ToolService` 最终累积的工具集（plugin + built-in + sub-agent delegate）
    /// 而非仅 `provider.agentTools(context:)` 的子集——这避免跨来源命名冲突逃逸到
    /// 聊天阶段才被 `assertUnique` 拦下。
    func validateToolNameUniqueness(
        provider: any LumiAgentToolProviding,
        builtInTools: [any LumiAgentTool]
    ) throws

    // MARK: - Boot

    /// 启动 LumiCore。
    ///
    /// 初始化所有核心模块。`editorFactory` 为可选：传入时 LumiCore 会在工具服务就绪后
    /// 自动调用工厂创建 `EditorService`，并同时注册抽象协议（`AbstractEditorServicing`）
    /// 与具体类型到服务表；不传则跳过 Editor bootstrap（适用于不需要编辑器的场景，例如
    /// 单元测试、CLI 工具）。
    ///
    /// `dataRootDirectory` 是 LumiAppKit 决定并传入的数据根父目录，LumiCore 负责
    /// 在其下物化 `Core/` 子目录作为核心数据库的物理位置。`dataRootDirectory` 始终
    /// 是父目录本身（而非 `Core/` 子目录），以保证 `coreDataDirectory` /
    /// `pluginDataDirectory(for:)` 的相对路径计算与历史一致。
    ///
    /// `builtInTools` 是运行期会由 `bootstrapToolContributions` 注入 `ToolService` 的
    /// 内置工具（如 `ChatService.builtInTools`）。传入后启动期校验就把 plugin 工具、
    /// 内置工具、sub-agent delegate 工具的并集一起查重，跨来源的命名冲突在 boot
    /// 阶段就会以 `LumiToolRegistrationError` 抛出。
    ///
    /// - Parameters:
    ///   - dataRootDirectory: 数据根父目录，由 LumiAppKit 决定。
    ///   - provider: Agent Tool 贡献者（通常是 `PluginService`）。
    ///   - builtInTools: 内置工具列表（如 `ChatService.builtInTools`），默认为空。
    ///   - editorFactory: Editor 工厂闭包，接收 provider，返回具体的 `EditorService` 实例。
    func boot<Service: AbstractEditorServicing>(
        dataRootDirectory: URL,
        provider: any LumiAgentToolProviding,
        builtInTools: [any LumiAgentTool],
        editorFactory: EditorBootstrapFactory<Service>?
    ) throws
}

// MARK: - SwiftUI Environment

/// SwiftUI 环境值：注入 `LumiCoreAccessing` 供视图树访问。
///
/// 默认值为 `nil`，因此未注入时插件视图会得到 `nil` 而非崩溃——可由调用方决定如何
/// 优雅降级（显示占位、跳过功能、抛错等）。这避免了「必须保证环境注入」的硬约束，
/// 让插件在 SwiftUI Preview 等场景下也能安全运行。
public extension EnvironmentValues {
    var lumiCore: LumiCoreAccessing? {
        get { self[LumiCoreEnvironmentKey.self] }
        set { self[LumiCoreEnvironmentKey.self] = newValue }
    }
}

private struct LumiCoreEnvironmentKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: LumiCoreAccessing? = nil
}