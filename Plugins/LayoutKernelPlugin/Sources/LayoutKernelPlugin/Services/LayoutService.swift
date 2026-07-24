import Foundation
import LumiKernel

/// 布局服务实现
@MainActor
public final class LayoutService: LayoutProviding {

    /// 布局状态（用于持久化）
    @Published public var state: LayoutStateInfo

    /// 原始布局状态（用于视图绑定）
    public let layoutState: LayoutState

    public init(initialState: LayoutStateInfo = LayoutStateInfo()) {
        self.state = initialState
        self.layoutState = LayoutState()
    }

    public func updateLayout(_ update: (inout LayoutStateInfo) -> Void) {
        update(&state)
    }
}
