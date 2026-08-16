import Foundation

/// 编辑器 Host Capability 总入口（契约 V2）。
///
/// 见 `docs/editor-kernel-plugin-rearchitecture-plan.md` §8。
/// 与旧 `EditorProviding`（视图/主题/插件注册的窄契约）并存：
/// 本协议由 `EditorHostPlugin` 实现并注册为 `EditorProvidingV2`，
/// 旧协议在 EditorService V2 Adapter 落地并完成消费者迁移后移除，
/// 届时本协议更名为 `EditorProviding`。
///
/// 并发与观察规则（§8.8）：
/// - 能力协议不继承 `ObservableObject`；状态经 `statePublisher` 观察，
///   且高频状态（选择等）不转发 Kernel 全局 `objectWillChange`。
/// - `statePublisher` 具有 CurrentValue 语义：新订阅者先收到当前快照。
/// - Publisher 不以 failure 结束；操作错误由 async throws 或结果对象返回。
@MainActor
public protocol EditorProvidingV2: AnyObject {
    /// 本 Host 实例绑定的作用域。从第一版契约开始携带，避免全局单例。
    var scope: EditorScope { get }

    /// 文档能力：打开、快照、保存、编辑事务。
    var documents: any EditorDocumentProviding { get }

    /// Session 能力：标签、Group、分栏与导航历史。
    var sessions: any EditorSessionProviding { get }

    /// 选择能力：多光标与选区。
    var selections: any EditorSelectionProviding { get }

    /// 导航能力：跳转、reveal 与 peek。
    var navigation: any EditorNavigationProviding { get }

    /// 命令能力：所有操作的统一入口。
    var commands: any EditorCommandProviding { get }

    /// 配置能力：分作用域设置解析与更新。
    var configuration: any EditorConfigurationProviding { get }

    /// Surface 能力：标准编辑器视图组装（Shell UI 插件消费）。
    var surface: any EditorSurfaceProviding { get }

    /// 诊断能力：问题快照与变更流（数据面）。
    var diagnostics: any EditorDiagnosticsProviding { get }

    /// 文档符号能力：当前文档符号树（数据面）。
    var documentSymbols: any EditorDocumentSymbolProviding { get }

    /// 面板能力：底部面板展示/收起。
    var panels: any EditorPanelProviding { get }

    /// 引用能力：引用/定义结果数据面。
    var references: any EditorReferencesProviding { get }

    /// 调用层级能力：caller/callee 会话数据面。
    var callHierarchy: any EditorCallHierarchyProviding { get }

    /// 工作区搜索能力：搜索执行与结果数据面。
    var workspaceSearch: any EditorWorkspaceSearchProviding { get }

    /// Diff 能力：工作副本 diff、任意两文本 diff 与逐块接受（Phase 7 §15.5）。
    var diff: any EditorDiffProviding { get }

    /// 扩展宿主能力：贡献包原子安装/撤回与能力可用性（§9）。
    var extensions: any EditorExtensionHosting { get }
}
