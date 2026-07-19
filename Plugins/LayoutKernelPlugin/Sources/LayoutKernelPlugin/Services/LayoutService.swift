import Foundation
import LumiKernel

/// 布局服务实现
@MainActor
public final class LayoutService: LayoutProviding {

    /// 布局状态
    @Published public var state: LayoutStateInfo

    public init(initialState: LayoutStateInfo = LayoutStateInfo()) {
        self.state = initialState
    }

    public func updateLayout(_ update: (inout LayoutStateInfo) -> Void) {
        update(&state)
    }
}