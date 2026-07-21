import Foundation

/// 工作区状态服务
///
/// 集中管理工作区的可见性与当前激活容器，由 `WorkspaceStatePlugin` 提供默认实现。
/// 插件通过命令式方法声明自己激活容器时希望的工作区状态。
/// View 层只读取，不直接修改。
@MainActor
public protocol WorkspaceStateProviding: AnyObject {
    // MARK: - 读取（View 层只读）

    /// Rail 视图是否可见
    var isRailVisible: Bool { get }
    /// Chat 区域是否可见
    var isChatVisible: Bool { get }
    /// 主内容区域是否可见
    var isContentVisible: Bool { get }
    /// ActivityBar 是否可见
    var isActivityBarVisible: Bool { get }
    /// 底部 Panel 是否可见
    var isPanelVisible: Bool { get }
    /// 当前激活的容器 ID
    var activeContainerID: String? { get }

    // MARK: - 命令式入口（插件可调用）

    func setRailVisible(_ visible: Bool)
    func setChatVisible(_ visible: Bool)
    func setContentVisible(_ visible: Bool)
    func setActivityBarVisible(_ visible: Bool)
    func setPanelVisible(_ visible: Bool)
    func activateContainer(id: String)

    // MARK: - 批量应用（插件切换容器时调用）

    /// 应用一组可见性变更；传 nil 表示不修改对应字段。
    func applyVisibility(
        rail: Bool?,
        chat: Bool?,
        content: Bool?,
        activityBar: Bool?,
        panel: Bool?
    )
}

/// 插件声明的工作区可见性偏好
public struct WorkspaceVisibility: Sendable {
    public var rail: Bool?
    public var chat: Bool?
    public var content: Bool?
    public var activityBar: Bool?
    public var panel: Bool?

    public init(
        rail: Bool? = nil,
        chat: Bool? = nil,
        content: Bool? = nil,
        activityBar: Bool? = nil,
        panel: Bool? = nil
    ) {
        self.rail = rail
        self.chat = chat
        self.content = content
        self.activityBar = activityBar
        self.panel = panel
    }

    /// 全部可见
    public static let allVisible = WorkspaceVisibility(
        rail: true, chat: true, content: true, activityBar: true, panel: true
    )

    /// 仅显示 Chat
    public static let chatOnly = WorkspaceVisibility(
        rail: false, chat: true, content: false, activityBar: true, panel: false
    )

    /// 仅显示 Content + Rail
    public static let contentWithRail = WorkspaceVisibility(
        rail: true, chat: false, content: true, activityBar: true, panel: true
    )
}