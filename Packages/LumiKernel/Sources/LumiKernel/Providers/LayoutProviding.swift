import Foundation

/// 布局能力协议
///
/// 定义 LumiCore 需要的布局管理功能，由 LayoutService 实现。
/// 包含工作区可见性管理（合并自原 WorkspaceStateProviding）。
@MainActor
public protocol LayoutProviding: ObservableObject {
    /// 布局状态（包含 @Published 属性，用于视图绑定）
    var layoutState: LayoutState { get }

    // MARK: - Workspace Visibility

    var isRailVisible: Bool { get }
    var isChatVisible: Bool { get }
    var isContentVisible: Bool { get }
    var isPanelVisible: Bool { get }
    var isPanelBottomVisible: Bool { get }

    // MARK: - Workspace Commands

    func setRailVisible(_ visible: Bool)
    func setChatVisible(_ visible: Bool)
    func setContentVisible(_ visible: Bool)
    func setPanelVisible(_ visible: Bool)
    func setPanelBottomVisible(_ visible: Bool)

    func activateContainer(id: String)
    func applyVisibility(rail: Bool?, chat: Bool?, content: Bool?, panel: Bool?)
    func addContainerObserver(_ observer: @escaping (String) -> Void)

    // MARK: - View Containers

    /// 所有视图容器（按 order 排序）
    var allViewContainers: [ViewContainerItem] { get }

    /// 按 ID 查询视图容器
    func viewContainer(id: String) -> ViewContainerItem?

    /// 注册视图容器
    func registerViewContainer(_ container: ViewContainerItem)

    /// 注销视图容器
    func unregisterViewContainer(id: String)

    // MARK: - Container

    var activeViewContainerID: String? { get }

    // MARK: - Section Info

    var activeSectionID: String { get }
    var activeSectionTitle: String { get }

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
