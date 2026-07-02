import Combine
import Foundation

/// LumiCore 布局状态管理器
/// 负责管理当前布局状态
@MainActor
public final class LumiLayoutState: ObservableObject {
    // MARK: - 当前激活视图容器

    @Published public var activeViewContainerID: String? {
        didSet {
            guard activeViewContainerID != oldValue else { return }
            // 如果外部直接修改了 Core 状态，可在此同步到上层 Store
        }
    }

    // MARK: - 可见性状态

    @Published public var chatSectionVisible: Bool = true
    @Published public var bottomPanelVisible: Bool = true

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
}
