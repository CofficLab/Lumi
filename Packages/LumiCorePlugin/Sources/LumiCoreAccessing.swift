import LumiCoreAgentTool
import LumiCoreLayout
import LumiCoreMessage
import LumiCoreProject
import LumiCoreStorage

// MARK: - LumiCoreAccessing

/// 视图与插件访问 LumiCore 核心状态的协议。
///
/// 该协议暴露**只读**且**频繁使用**的 API，供 SwiftUI 视图（App + 插件）通过
/// `@Environment(\.lumiCore)` 安全获取。它刻意不暴露任何修改内部状态的能力，
/// 以保证视图层无法污染内核状态。
///
/// 运行期的注册与编排（`registerService` 等）请使用
/// `LumiCoreBootstrapping` 协议。
///
/// - Important: 实现必须为 class（`AnyObject`），因为协议内含可变状态；
///
/// 自 LumiCore 迁移到 `final class` 后,`LumiCoreAccessing` 继承 `ObservableObject`,
/// 允许 SwiftUI 视图通过 `@EnvironmentObject` 完整观察内核状态变化。
///   所有访问必须在主线程（`@MainActor`）。
@MainActor
public protocol LumiCoreAccessing: ObservableObject {
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

    /// Agent 工具功能组件。per-request 动态注入改造后，暴露 `buildToolSet` 供
    /// `SendPipeline` 在每次发消息时构建本次请求的工具集（按当前 context 收集
    /// 插件工具、内置工具、子 Agent 工具，软去重后返回 per-request `ToolService`）。
    var agentToolComponent: AgentToolComponent { get }

    /// 聊天服务（init 时由 `ChatServiceFactory` 创建并自动注册）。
    var chatService: (any LumiChatServicing) { get }

    /// 编辑器服务（`init(editorFactory:)` 传入工厂时创建；不传则为 nil）。
    var editorService: (any AbstractEditorServicing)? { get }
}