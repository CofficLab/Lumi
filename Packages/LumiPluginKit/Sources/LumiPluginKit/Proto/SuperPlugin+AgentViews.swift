import AppKit
import SwiftUI
import Foundation

/// Agent 模式视图扩展
extension SuperPlugin {
    /// 默认实现：不提供状态栏左侧视图
    @MainActor public func addStatusBarLeadingView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供状态栏中间视图
    @MainActor public func addStatusBarCenterView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供状态栏右侧视图
    @MainActor public func addStatusBarTrailingView(activeIcon: String?) -> AnyView? { nil }
}
