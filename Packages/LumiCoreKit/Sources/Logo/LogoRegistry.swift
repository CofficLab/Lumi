import Foundation
import SwiftUI

/// Logo 注册表
///
/// 收集所有插件贡献的 ``LogoItem``，按 ``LogoItem/order`` 选出全局最高优先级的 Logo。
/// 无插件贡献时回退到内置的 Logo。
@MainActor
public final class LogoRegistry: ObservableObject {
    /// 全局共享实例
    public static let shared = LogoRegistry()
    
    /// 当前最高优先级的 Logo 项（已缓存，注册时刷新）
    @Published public var bestItem: LogoItem?

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
