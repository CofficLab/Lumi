import AppKit
import SwiftUI
import Foundation

/// Agent 模式视图扩展
///
/// 为状态栏视图方法提供默认实现。
/// 插件可以选择性地实现这些方法来贡献 UI。
extension SuperPlugin {
    /// 默认实现：不提供状态栏左侧视图
    @MainActor func addStatusBarLeadingView() -> AnyView? { nil }

    /// 默认实现：不提供状态栏右侧视图
    @MainActor func addStatusBarTrailingView() -> AnyView? { nil }
}
