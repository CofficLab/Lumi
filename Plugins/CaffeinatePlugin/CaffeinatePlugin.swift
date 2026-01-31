import AppKit
import Foundation
import MagicKit
import SwiftUI
import Combine
import OSLog

/// 防休眠插件：阻止系统休眠，支持定时和手动控制
/// 防休眠插件：阻止系统休眠，支持定时和手动控制
actor CaffeinatePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "☕️"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "CaffeinatePlugin"

    /// 插件显示名称
    static var displayName: String = "防休眠"

    /// 插件功能描述
    static var description: String = "阻止系统休眠，支持定时和手动控制"

    /// 插件图标名称
    static var iconName: String = "bolt"

    /// 是否可配置
    static var isConfigurable: Bool = true
    
    /// 注册顺序
    static var order: Int { 7 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = CaffeinatePlugin()
    
    /// 初始化方法
    init() {
        os_log("CaffeinatePlugin initialized")
    }

    // MARK: - UI Contributions

    /// 添加状态栏右侧视图
    /// - Returns: 状态栏右侧视图
    @MainActor func addStatusBarTrailingView() -> AnyView? {
        return AnyView(CaffeinateStatusView())
    }

    /// 添加系统菜单栏菜单项
    /// - Returns: 系统菜单栏菜单项数组
    @MainActor func addStatusBarMenuItems() -> [NSMenuItem]? {
        let manager = CaffeinateManager.shared
        var items: [NSMenuItem] = []
        let handler = CaffeinateActionHandler.shared

        // 防休眠开关菜单项
        let toggleItem = NSMenuItem(
            title: manager.isActive ? "停止阻止休眠" : "阻止系统休眠",
            action: #selector(CaffeinateActionHandler.toggleCaffeinate(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = handler
        toggleItem.isEnabled = true // 强制启用
        items.append(toggleItem)

        // 如果已激活，显示停止子菜单
        if manager.isActive {
            items.append(NSMenuItem.separator())

            // 常用时间选项
            for durationOption in CaffeinateManager.commonDurations {
                let item = NSMenuItem(
                    title: "切换时长: \(durationOption.displayName)",
                    action: #selector(CaffeinateActionHandler.activateWithDuration(_:)),
                    keyEquivalent: ""
                )
                item.tag = durationOption.hashValue
                item.target = handler
                item.isEnabled = true // 强制启用
                items.append(item)
            }
        }

        return items
    }
}

// MARK: - Action Handler

/// 辅助类，用于处理菜单点击事件（因为 Actor 不能直接作为 Target）
fileprivate class CaffeinateActionHandler: NSObject, NSMenuItemValidation {
    /// 单例实例，确保生命周期
    static let shared = CaffeinateActionHandler()

    /// 切换防休眠状态
    @objc func toggleCaffeinate(_ sender: Any?) {
        os_log("CaffeinateActionHandler: toggleCaffeinate called")
        CaffeinateManager.shared.toggle()
    }

    /// 使用指定时长激活防休眠
    @objc func activateWithDuration(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else { return }
        os_log("CaffeinateActionHandler: activateWithDuration called")
        
        // 根据菜单项的 tag 找到对应的时长选项
        if let option = CaffeinateManager.commonDurations.first(where: { $0.hashValue == menuItem.tag }) {
            // 先停止当前的
            if CaffeinateManager.shared.isActive {
                CaffeinateManager.shared.deactivate()
            }
            // 使用新时长激活
            CaffeinateManager.shared.activate(duration: option.timeInterval)
        }
    }
    
    /// 验证菜单项是否可用
    /// - Parameter menuItem: 菜单项
    /// - Returns: 是否可用
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        os_log("CaffeinateActionHandler: Validating menu item '\(menuItem.title)'")
        return true
    }
}
