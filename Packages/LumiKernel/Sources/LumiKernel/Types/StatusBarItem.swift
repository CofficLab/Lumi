import Foundation
import SwiftUI

// MARK: - Status Bar Placement

/// 状态栏位置
public enum StatusBarPlacement: Sendable, Equatable {
    /// 左侧
    case leading
    /// 中间
    case center
    /// 右侧
    case trailing
}

// MARK: - Status Bar Item

/// 状态栏项
///
/// 插件通过 `kernel.registerStatusBarItem()` 注册状态栏内容。
@MainActor
public struct StatusBarItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let placement: StatusBarPlacement
    public let makeStatusBarView: (@MainActor @Sendable () -> AnyView)?
    public let makePopoverView: @MainActor @Sendable () -> AnyView

    public init<Popover: View>(
        id: String,
        title: String,
        systemImage: String,
        placement: StatusBarPlacement = .trailing,
        @ViewBuilder popover: @escaping @MainActor @Sendable () -> Popover
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.placement = placement
        self.makeStatusBarView = nil
        self.makePopoverView = { AnyView(popover()) }
    }

    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        placement: StatusBarPlacement = .trailing,
        @ViewBuilder statusBarView: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.placement = placement
        self.makeStatusBarView = { AnyView(statusBarView()) }
        self.makePopoverView = { AnyView(EmptyView()) }
    }
}
