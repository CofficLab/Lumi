import Foundation
import SwiftUI

// MARK: - LumiCoreAccessing

/// 视图与插件访问 LumiCore 核心状态的协议。
///
/// 该协议暴露**只读**且**频繁使用**的 API，供 SwiftUI 视图（App + 插件）通过
/// `@Environment(\.lumiCore)` 安全获取。它刻意不暴露任何修改内部状态的能力，
/// 以保证视图层无法污染内核状态。
///
/// 运行期的注册与编排（`registerService`、`bootstrapToolContributions` 等）请使用
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

    /// 存储功能组件。归拢路径计算(coreDataDirectory / pluginDataDirectory(for:))。
    var storage: StorageComponent { get }

    /// Logo 功能组件。收集插件贡献的 Logo 项并选出最高优先级者。
    var logoComponent: LogoComponent { get }

    /// 项目功能组件。封装 `ProjectState`,
    /// 对外暴露只读的 `currentProject` / `projects` + 写方法门面。
    var projectComponent: ProjectComponent { get }

    /// 布局功能组件。封装 `LumiLayoutState`,转发 objectWillChange。
    /// 注意:本组件不收敛 state 字段——外部可直接读写 `component.state.xxx`
    /// (SwiftUI Binding 惯法天然要求外部能写)。
    var layoutComponent: LayoutComponent { get }

    /// 聊天服务（init 时由 `ChatServiceFactory` 创建并自动注册）。
    var chatService: (any LumiChatServicing) { get }

    /// 编辑器服务（`init(editorFactory:)` 传入工厂时创建；不传则为 nil）。
    var editorService: (any AbstractEditorServicing)? { get }

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
    /// ChatService 工厂闭包类型。init 时传入,接收 core 数据库目录。
    /// 工厂创建的 ChatService 的 lumiCore 引用应留空(nil),由调用方在
    /// LumiCore 创建后调 `chatService.configure(lumiCore:)` 回填。
    typealias ChatServiceFactory = @MainActor (URL) -> any LumiChatServicing

    // MARK: - Service Registry

    /// 注册一个服务实例，供 `makePluginContext` 自动注入。
    func registerService<T>(_ type: T.Type, _ instance: T)

    /// 从注册表解析已注册的服务实例。
    func resolveService<T>(_ type: T.Type) -> T?

    // MARK: - Tool Service

    /// 启动 `ToolService` 并注入运行环境。
    ///
    /// `builtInTools` 是运行期会由 `bootstrapToolContributions` 注入 `ToolService` 的
    /// 内置工具（如 `ChatService.builtInTools`）。把它们传入启动期校验，让 init 阶段
    /// 就能拦截跨来源的命名冲突。
    func bootstrapToolService(
        provider: any AgentToolProviding,
        builtInTools: [any LumiAgentTool]
    ) throws

    /// 编排 Agent Tool 工具的注册与注入。
    ///
    /// 把 `provider` 提供的插件工具、内置工具和子 Agent 工具注册到 `ToolService`，
    /// 并把 `ToolService` 关联到 `ChatService`。App 层无需直接接触 `ToolService`、
    /// `LumiAgentTool` 或 `SubAgentDelegateTool` 任何细节。
    func bootstrapToolContributions(
        provider: any AgentToolProviding,
        context: LumiPluginContext,
        builtInTools: [any LumiAgentTool]
    )

    /// 启动期工具名校验：让 init 阶段就能拦截插件侧的配置冲突。
    ///
    /// 校验的是 `ToolService` 最终累积的工具集（plugin + built-in + sub-agent delegate）
    /// 而非仅 `provider.agentTools(context:)` 的子集——这避免跨来源命名冲突逃逸到
    /// 聊天阶段才被 `assertUnique` 拦下。
    func validateToolNameUniqueness(
        provider: any AgentToolProviding,
        builtInTools: [any LumiAgentTool]
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
