import AppKit
import Foundation
import MagicKit
import SwiftUI
import Combine
import OSLog

/// 防休眠插件：阻止系统休眠，支持定时和手动控制
class CaffeinatePlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
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

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = CaffeinatePlugin()

    /// 私有初始化方法
    private override init() {
        super.init()
        os_log("CaffeinatePlugin initialized")
    }

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // MARK: - UI Contributions

    /// 添加工具栏前导视图
    /// - Returns: 工具栏前导视图
    func addToolBarLeadingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加工具栏右侧视图
    /// - Returns: 工具栏右侧视图
    func addToolBarTrailingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加状态栏左侧视图
    /// - Returns: 状态栏左侧视图
    func addStatusBarLeadingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加状态栏右侧视图
    /// - Returns: 状态栏右侧视图
    func addStatusBarTrailingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return AnyView(CaffeinateStatusView())
    }

    /// 添加详情视图
    /// - Returns: 详情视图
    func addDetailView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加列表视图
    /// - Parameters:
    ///   - tab: 标签页
    ///   - project: 项目对象
    /// - Returns: 列表视图
    func addListView(tab: String, project: Project?) -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加侧边栏视图
    /// - Returns: 要添加到侧边栏的视图，如果不需要则返回nil
    func addSidebarView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加系统菜单栏菜单项
    /// - Returns: 系统菜单栏菜单项数组
    func addStatusBarMenuItems() -> [NSMenuItem]? {
        guard isUserEnabled else { return nil }

        let manager = CaffeinateManager.shared
        var items: [NSMenuItem] = []

        // 防休眠开关菜单项
        let toggleItem = NSMenuItem(
            title: manager.isActive ? "停止阻止休眠" : "阻止系统休眠",
            action: #selector(toggleCaffeinate),
            keyEquivalent: ""
        )
        toggleItem.target = self
        items.append(toggleItem)

        // 如果已激活，显示停止子菜单
        if manager.isActive {
            items.append(NSMenuItem.separator())

            // 常用时间选项
            for durationOption in CaffeinateManager.commonDurations {
                let item = NSMenuItem(
                    title: "切换时长: \(durationOption.displayName)",
                    action: #selector(activateWithDuration(_:)),
                    keyEquivalent: ""
                )
                item.tag = durationOption.hashValue
                item.target = self
                items.append(item)
            }
        }

        return items
    }
}

// MARK: - Menu Actions

extension CaffeinatePlugin {
    /// 切换防休眠状态
    @objc private func toggleCaffeinate() {
        CaffeinateManager.shared.toggle()
    }

    /// 使用指定时长激活防休眠
    @objc private func activateWithDuration(_ sender: NSMenuItem) {
        // 根据菜单项的 tag 找到对应的时长选项
        if let option = CaffeinateManager.commonDurations.first(where: { $0.hashValue == sender.tag }) {
            // 先停止当前的
            if CaffeinateManager.shared.isActive {
                CaffeinateManager.shared.deactivate()
            }
            // 使用新时长激活
            CaffeinateManager.shared.activate(duration: option.timeInterval)
        }
    }
}

// MARK: - PluginRegistrant

extension CaffeinatePlugin {
    /// 注册插件到插件注册表
    static func register() {
        guard enable else { return }

        Task {
            await PluginRegistry.shared.register(id: id, order: 7) {
                CaffeinatePlugin.shared
            }
        }
    }
}
