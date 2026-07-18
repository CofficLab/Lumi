import Foundation
import os.log
import SwiftUI

/// LumiCore 的"Logo"功能组件。
///
/// 收集所有插件贡献的 ``LogoItem``，按 ``LogoItem/order`` 选出全局最高优先级的 Logo。
/// 无插件贡献时回退到内置的 Logo。
@MainActor
public final class LogoComponent: ObservableObject {
    /// 当前最高优先级的 Logo 项
    @Published public private(set) var bestItem: LogoItem?

    public init() {}

    /// 批量注册 Logo 项，保留 order 最高的一项
    ///
    /// 直接同步赋值：整个类已标记 `@MainActor`，调用方也在主线程，
    /// 无需 `Task { @MainActor }` 包装（后者会把赋值推迟到下一个 runloop，
    /// 导致首次渲染 LogoView 时 `bestItem == nil` 走到 fallback 分支）。
    ///
    /// - Parameter items: 来自各插件的 Logo 贡献
    public func register(_ items: [LogoItem]) {
        self.bestItem = items.max(by: { $0.order < $1.order })
    }
}