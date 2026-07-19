import Foundation
import SwiftUI

// MARK: - Logo Scene

/// Logo 显示场景
///
/// 不同场景可能有不同的视觉要求和动画行为。
public enum LogoScene: String, CaseIterable, Sendable {
    case general
    case appIcon
    case about
    /// 系统菜单栏图标：恒为单色模板图（由系统统一着色），无动画。
    case statusBar
    case custom
}

// MARK: - Logo Item

/// 插件贡献的 Logo 项
///
/// 插件通过 `kernel.registerLogoItem()` 注册 Logo，框架根据 `order` 值选出最高优先级的 Logo 用于显示。
///
/// - 每个场景（如 about、statusBar 等）会独立选择最高优先级的 Logo
/// - 如果多个插件贡献相同 id 的项，行为未定义
/// - `order` 值越大优先级越高（由内核自动从插件继承）
/// - 可选的 `overlay` 视图会叠加在基础 Logo 视图之上
@MainActor
public struct LogoItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let makeView: @MainActor @Sendable (LogoScene) -> AnyView
    public let makeOverlay: (@MainActor @Sendable (LogoScene) -> AnyView)?

    /// 公开初始化器（不包含 order）
    public init<V: View>(
        id: String,
        @ViewBuilder makeView: @escaping @MainActor @Sendable (LogoScene) -> V
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.makeView = { scene in AnyView(makeView(scene)) }
        self.makeOverlay = nil
    }

    /// 公开初始化器（带 overlay，不包含 order）
    public init<V: View, O: View>(
        id: String,
        @ViewBuilder makeView: @escaping @MainActor @Sendable (LogoScene) -> V,
        @ViewBuilder makeOverlay: @escaping @MainActor @Sendable (LogoScene) -> O
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.makeView = { scene in AnyView(makeView(scene)) }
        self.makeOverlay = { scene in AnyView(makeOverlay(scene)) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<V: View>(
        id: String,
        order: Int,
        @ViewBuilder makeView: @escaping @MainActor @Sendable (LogoScene) -> V
    ) {
        self.id = id
        self.order = order
        self.makeView = { scene in AnyView(makeView(scene)) }
        self.makeOverlay = nil
    }

    /// 内部初始化器（带 overlay，用于内核设置 order）
    internal init<V: View, O: View>(
        id: String,
        order: Int,
        @ViewBuilder makeView: @escaping @MainActor @Sendable (LogoScene) -> V,
        @ViewBuilder makeOverlay: @escaping @MainActor @Sendable (LogoScene) -> O
    ) {
        self.id = id
        self.order = order
        self.makeView = { scene in AnyView(makeView(scene)) }
        self.makeOverlay = { scene in AnyView(makeOverlay(scene)) }
    }
}