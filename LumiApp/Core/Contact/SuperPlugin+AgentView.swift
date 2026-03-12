import AppKit
import SwiftUI

// MARK: - Agent View Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供侧边栏视图
    @MainActor func addSidebarView() -> AnyView? { nil }

    /// 默认实现：不提供中间栏视图
    @MainActor func addMiddleView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏头部视图
    @MainActor func addDetailHeaderView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏中间视图
    @MainActor func addDetailMiddleView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏底部视图
    @MainActor func addDetailBottomView() -> AnyView? { nil }
}
