import Foundation
import SwiftUI

// MARK: - Title Toolbar Placement

/// 标题栏工具栏位置
public enum TitleToolbarPlacement: Sendable {
    /// 左侧
    case leading
    /// 中间
    case center
    /// 右侧
    case trailing
}

// MARK: - Title Toolbar Item

/// 标题栏工具栏项
///
/// 定义一个可在窗口标题栏显示的工具栏项。
/// 插件通过 `kernel.registerTitleToolbarItem()` 注册工具栏项。
public struct TitleToolbarItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let placement: TitleToolbarPlacement
    public let order: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        placement: TitleToolbarPlacement = .center,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.placement = placement
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}