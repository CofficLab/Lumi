import Combine
import Foundation

/// LumiCore 布局状态管理器
/// 负责管理当前激活的视图容器 ID（内存存储）
@MainActor
public final class LumiLayoutState: ObservableObject {
    // MARK: - 当前激活视图容器

    @Published public var activeViewContainerID: String?

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
