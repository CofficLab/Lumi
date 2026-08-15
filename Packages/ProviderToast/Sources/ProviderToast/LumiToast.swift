import Foundation
import SwiftUI

// MARK: - Toast

/// 一条内核级 Toast 消息,用于向用户做瞬时提示。
///
/// 消费方通过 `kernel.toast?.show(...)` 发出;
/// 具体的展示(渲染、队列、自动消失策略)由实现 `ToastProviding` 的
/// 插件决定。该类型为纯值类型且 `Sendable`,可安全跨线程传递。
public struct LumiToast: Sendable, Equatable {
    /// 标题。
    public let title: String
    /// 可选副标题。
    public let detail: String?
    /// 展示风格(由实现映射为图标与色调)。
    public let style: LumiToastStyle
    /// 自定义展示时长(秒);`nil` 表示使用实现的默认时长。
    public let duration: TimeInterval?

    public init(
        title: String,
        detail: String? = nil,
        style: LumiToastStyle = .info,
        duration: TimeInterval? = nil
    ) {
        self.title = title
        self.detail = detail
        self.style = style
        self.duration = duration
    }
}

/// Toast 的展示风格。
public enum LumiToastStyle: String, Sendable {
    case info
    case success
    case warning
    case error
}
