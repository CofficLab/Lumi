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

    static let navigationId = "\(id).settings"

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

    /// 提供导航入口
    /// - Returns: 导航入口数组
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: "防休眠设置",
                icon: "bolt.fill",
                pluginId: Self.id
            ) {
                CaffeinateSettingsView()
            }
        ]
    }

    /// 添加系统菜单栏菜单项
    /// - Returns: 系统菜单栏菜单项数组
    @MainActor func addStatusBarMenuItems() -> [NSMenuItem]? {
        let manager = CaffeinateManager.shared
        var items: [NSMenuItem] = []
        let handler = CaffeinateActionHandler.shared

        if manager.isActive {
            let stopItem = NSMenuItem(
                title: "停止阻止休眠",
                action: #selector(CaffeinateActionHandler.toggleCaffeinate(_:)),
                keyEquivalent: ""
            )
            stopItem.target = handler
            stopItem.isEnabled = true
            items.append(stopItem)
        }

        items.append(NSMenuItem.separator())

        let allowDisplayItem = NSMenuItem(
            title: CaffeinateManager.SleepMode.systemOnly.displayName,
            action: #selector(CaffeinateActionHandler.activateAllowDisplay(_:)),
            keyEquivalent: ""
        )
        allowDisplayItem.target = handler
        allowDisplayItem.isEnabled = true
        allowDisplayItem.state = manager.mode == .systemOnly ? .on : .off
        items.append(allowDisplayItem)

        let preventDisplayItem = NSMenuItem(
            title: CaffeinateManager.SleepMode.systemAndDisplay.displayName,
            action: #selector(CaffeinateActionHandler.activatePreventDisplay(_:)),
            keyEquivalent: ""
        )
        preventDisplayItem.target = handler
        preventDisplayItem.isEnabled = true
        preventDisplayItem.state = manager.mode == .systemAndDisplay ? .on : .off
        items.append(preventDisplayItem)

        let turnOffDisplayItem = NSMenuItem(
            title: "阻止休眠，立刻关闭屏幕",
            action: #selector(CaffeinateActionHandler.activateAndTurnOffDisplay(_:)),
            keyEquivalent: ""
        )
        turnOffDisplayItem.target = handler
        turnOffDisplayItem.isEnabled = true
        items.append(turnOffDisplayItem)

        items.append(NSMenuItem.separator())

        for durationOption in CaffeinateManager.commonDurations {
            let item = NSMenuItem(
                title: "时长: \(durationOption.displayName)",
                action: #selector(CaffeinateActionHandler.activateWithDuration(_:)),
                keyEquivalent: ""
            )
            item.tag = durationOption.hashValue
            item.target = handler
            item.isEnabled = true
            item.state = manager.isActive && manager.duration == durationOption.timeInterval ? .on : .off
            items.append(item)
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

    @objc func activateAllowDisplay(_ sender: Any?) {
        activate(mode: .systemOnly)
    }

    @objc func activatePreventDisplay(_ sender: Any?) {
        activate(mode: .systemAndDisplay)
    }

    @objc func activateAndTurnOffDisplay(_ sender: Any?) {
        if CaffeinateManager.shared.isActive {
            CaffeinateManager.shared.deactivate()
        }
        // 默认使用永久时长，因为这是一个立即动作
        CaffeinateManager.shared.activateAndTurnOffDisplay(duration: 0)
    }

    /// 使用指定时长激活防休眠
    @objc func activateWithDuration(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else { return }
        os_log("CaffeinateActionHandler: activateWithDuration called")
        
        // 根据菜单项的 tag 找到对应的时长选项
        if let option = CaffeinateManager.commonDurations.first(where: { $0.hashValue == menuItem.tag }) {
            activate(mode: CaffeinateManager.shared.mode, duration: option.timeInterval)
        }
    }

    private func activate(mode: CaffeinateManager.SleepMode, duration: TimeInterval = 0) {
        if CaffeinateManager.shared.isActive {
            CaffeinateManager.shared.deactivate()
        }
        CaffeinateManager.shared.activate(mode: mode, duration: duration)
    }
    
    /// 验证菜单项是否可用
    /// - Parameter menuItem: 菜单项
    /// - Returns: 是否可用
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let manager = CaffeinateManager.shared

        if menuItem.action == #selector(CaffeinateActionHandler.activateAllowDisplay(_:)) {
            menuItem.state = manager.mode == .systemOnly ? .on : .off
        } else if menuItem.action == #selector(CaffeinateActionHandler.activatePreventDisplay(_:)) {
            menuItem.state = manager.mode == .systemAndDisplay ? .on : .off
        } else if menuItem.action == #selector(CaffeinateActionHandler.activateWithDuration(_:)) {
            menuItem.state = manager.isActive && manager.duration == durationForTag(menuItem.tag) ? .on : .off
        }

        return true
    }

    private func durationForTag(_ tag: Int) -> TimeInterval? {
        CaffeinateManager.commonDurations.first(where: { $0.hashValue == tag })?.timeInterval
    }
}
