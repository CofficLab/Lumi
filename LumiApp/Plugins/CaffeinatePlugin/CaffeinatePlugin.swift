import AppKit
import Combine
import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 防休眠插件：阻止系统休眠，支持定时和手动控制
/// 防休眠插件：阻止系统休眠，支持定时和手动控制
actor CaffeinatePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "☕️"

    /// 是否启用该插件
    nonisolated(unsafe) static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    nonisolated(unsafe) static var id: String = "CaffeinatePlugin"

    static let navigationId = "\(id).settings"

    /// 插件显示名称
    nonisolated(unsafe) static var displayName: String = "Anti-Sleep"

    /// 插件功能描述
    nonisolated(unsafe) static var description: String = "Prevent system sleep with timer and manual control"

    /// 插件图标名称
    nonisolated(unsafe) static var iconName: String = "bolt"

    /// 是否可配置
    nonisolated(unsafe) static var isConfigurable: Bool = true

    /// 注册顺序
    nonisolated(unsafe) static var order: Int { 7 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String {
        Self.id
    }

    nonisolated(unsafe) static let shared = CaffeinatePlugin()

    // MARK: - UI Contributions

    /// 添加状态栏弹窗视图
    /// - Returns: 要添加到状态栏弹窗的视图，如果不需要则返回nil
    @MainActor func addStatusBarPopupView() -> AnyView? {
        AnyView(CaffeinateStatusBarPopupView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(CaffeinatePlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
