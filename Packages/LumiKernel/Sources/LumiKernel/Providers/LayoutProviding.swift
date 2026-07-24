import Foundation

/// 布局能力协议
///
/// 定义 LumiCore 需要的布局管理功能，由 LayoutService 实现。
/// 包含工作区可见性管理（合并自原 WorkspaceStateProviding）。
@MainActor
public protocol LayoutProviding: ObservableObject {
    /// 布局状态（轻量级信息，用于持久化）
    var state: LayoutStateInfo { get }

    /// 原始布局状态（包含 @Published 属性，用于视图绑定）
    var layoutState: LayoutState { get }

    /// 更新布局
    func updateLayout(_ update: (inout LayoutStateInfo) -> Void)

    // MARK: - Workspace Visibility

    var isRailVisible: Bool { get }
    var isChatVisible: Bool { get }
    var isContentVisible: Bool { get }
    var isActivityBarVisible: Bool { get }
    var isPanelVisible: Bool { get }

    // MARK: - Workspace Commands

    func setRailVisible(_ visible: Bool)
    func setChatVisible(_ visible: Bool)
    func setContentVisible(_ visible: Bool)
    func setActivityBarVisible(_ visible: Bool)
    func setPanelVisible(_ visible: Bool)

    func activateContainer(id: String)
    func applyVisibility(rail: Bool?, chat: Bool?, content: Bool?, activityBar: Bool?, panel: Bool?)
    func addContainerObserver(_ observer: @escaping (String) -> Void)

    // MARK: - Container

    var activeViewContainerID: String? { get }

    // MARK: - Rail Tabs

    var activeRailTabID: String { get }
    func presentRailTab(id: String)

    // MARK: - Bottom Panel

    var bottomPanelVisible: Bool { get }
    func presentBottomTab(id: String, viewContainerID: String)

    // MARK: - Dividers

    func railDivider(for viewContainerID: String, fallback: CGFloat?) -> CGFloat
    func setRailDivider(_ position: CGFloat, for viewContainerID: String)

    func chatSectionDivider(for viewContainerID: String, layout: LumiChatSectionLayout, fallback: CGFloat?) -> CGFloat
    func setChatSectionDivider(_ position: CGFloat, for viewContainerID: String, layout: LumiChatSectionLayout)

    func bottomPanelDivider(for viewContainerID: String, fallback: CGFloat?) -> CGFloat
    func setBottomPanelDivider(_ position: CGFloat, for viewContainerID: String)
}
