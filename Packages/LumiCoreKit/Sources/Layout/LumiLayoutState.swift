import Combine
import Foundation

/// LumiCore 布局状态管理器
/// 负责管理当前布局状态
///
/// 状态变更时会通过 `NotificationCenter` 发出事件，
/// 插件可监听通知进行持久化等响应操作，内核本身不感知插件存在。
@MainActor
public final class LumiLayoutState: ObservableObject, LumiBottomPanelLayoutPresenting {
    // MARK: - 当前激活视图容器

    @Published public var activeViewContainerID: String? {
        didSet {
            guard activeViewContainerID != oldValue else { return }
            NotificationCenter.postActiveViewContainerIDDidChange(containerID: activeViewContainerID)
        }
    }

    // MARK: - 可见性状态

    @Published public var chatSectionVisible: Bool = true {
        didSet {
            guard chatSectionVisible != oldValue else { return }
            NotificationCenter.postChatSectionVisibleDidChange(visible: chatSectionVisible)
        }
    }
    @Published public var bottomPanelVisible: Bool = true {
        didSet {
            guard bottomPanelVisible != oldValue else { return }
            NotificationCenter.postBottomPanelVisibleDidChange(visible: bottomPanelVisible)
        }
    }

    // MARK: - 面板状态

    @Published public var activeRailTabID: String = "explorer" {
        didSet {
            guard activeRailTabID != oldValue else { return }
            NotificationCenter.postActiveRailTabIDDidChange(railTabID: activeRailTabID)
        }
    }
    @Published public var activeBottomTabID: String = "editor-bottom-problems" {
        didSet {
            guard activeBottomTabID != oldValue else { return }
            NotificationCenter.postActiveBottomTabIDDidChange(bottomTabID: activeBottomTabID)
        }
    }
    @Published private(set) public var bottomPanelFocusGeneration = 0

    // MARK: - 初始化

    public init() {}

    // MARK: - 公开方法

    /// 激活指定视图容器
    public func activateViewContainer(id: String) {
        activeViewContainerID = id
    }

    /// 清除当前激活的视图容器
    public func clearActiveViewContainer() {
        activeViewContainerID = nil
    }

    // MARK: - LumiBottomPanelLayoutPresenting

    public func presentRailTab(id: String) {
        activeRailTabID = id
    }

    public func presentBottomTab(id: String, viewContainerID: String) {
        activeBottomTabID = id
        bottomPanelFocusGeneration += 1
    }
}
