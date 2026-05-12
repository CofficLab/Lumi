import Combine
import Foundation
import SwiftUI
import os
import MagicKit

/// 布局持久化插件
///
/// 负责观察 LayoutVM 和 PluginVM 中的布局状态变化并持久化到磁盘，
/// 以及在应用启动时自动恢复上次的布局状态。
///
/// ## 数据流
///
/// 1. **恢复**：应用启动 → `LayoutPersistenceAnchor.onAppear` → 从 LocalStore 读取 → 写入 LayoutVM / PluginVM
/// 2. **保存**：用户操作 / SplitView 拖拽 → LayoutVM / PluginVM 属性变化 → `onChange` 监听 → 写入 LocalStore
///
/// ## 观察的数据
///
/// - `PluginVM.activePanelIcon`：活动栏选中的图标
/// - `LayoutVM.selectedAgentSidebarTabId`：Agent 模式侧边栏 Tab
/// - `LayoutVM.selectedAgentDetailId`：Agent 模式 Detail 视图
/// - `LayoutVM.layoutRatios`：分栏布局宽度比例（由 SplitViewPersistence 组件更新）
actor LayoutPlugin: SuperPlugin, SuperLog {
    static let shared = LayoutPlugin()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated static let emoji = "📐"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = "Layout"
    static let displayName: String = "Layout Persistence"
    static let description: String = "Persist and restore layout state across app launches"
    static let iconName: String = "sidebar.left"
    static let isConfigurable: Bool = false
    static var order: Int { 1 }

    nonisolated var instanceLabel: String { Self.id }

    // MARK: - Root View（布局持久化锚点）

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(LayoutPersistenceAnchor(content: content()))
    }
}

// MARK: - Layout Persistence Anchor

/// 布局持久化锚点视图
///
/// 作为 `addRootView` 注入的全局透明视图，承担两个职责：
/// 1. **恢复**：首次出现时从本地存储读取已保存的布局状态，写入 LayoutVM / PluginVM。
/// 2. **保存**：监听 LayoutVM / PluginVM 的属性变化，自动持久化到本地存储。
///
/// 此视图不渲染任何可见内容，仅作为生命周期锚点。
private struct LayoutPersistenceAnchor<Content: View>: View {
    @EnvironmentObject private var layoutVM: LayoutVM
    @EnvironmentObject private var pluginVM: PluginVM

    let content: Content

    /// 标记是否已完成首次恢复，避免恢复触发 onChange 又写回存储
    @State private var hasRestored = false

    /// Combine 订阅集合
    @State private var cancellables = Set<AnyCancellable>()
    var body: some View {
        ZStack {
            content

            // 不依赖 content 本身是否可见；这个透明锚点负责触发生命周期。
            Color.clear
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .onAppear {
                    if LayoutPlugin.verbose {
                        LayoutPlugin.logger.info("\(LayoutPlugin.t)生命周期锚点 appeared")
                    }
                    restoreLayout()
                    startObserving()
                }
                .task {
                    // 某些场景下 `EmptyView` 包装链不会稳定触发 onAppear，
                    // task 作为兜底，配合内部 guard 保证幂等。
                    restoreLayout()
                    startObserving()
                }
                .accessibilityHidden(true)
            }
            .onChange(of: layoutVM.selectedAgentSidebarTabId) { oldValue, newValue in
                guard hasRestored else { return }
                guard oldValue != newValue else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)侧边栏 Tab 变更: \(oldValue) → \(newValue)")
                }
                LayoutPluginLocalStore.shared.saveSelectedAgentSidebarTabId(newValue)
            }
            .onChange(of: layoutVM.selectedAgentDetailId) { oldValue, newValue in
                guard hasRestored else { return }
                guard oldValue != newValue else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)Detail 变更: \(oldValue) → \(newValue)")
                }
                LayoutPluginLocalStore.shared.saveSelectedAgentDetailId(newValue)
            }
    }

    // MARK: - Restore

    /// 从本地存储恢复布局状态
    private func restoreLayout() {
        guard !hasRestored else { return }
        hasRestored = true

        let store = LayoutPluginLocalStore.shared

        // 恢复活动栏图标
        if let savedIcon = store.loadActivePanelIcon() {
            if LayoutPlugin.verbose {
                LayoutPlugin.logger.info("\(LayoutPlugin.t)恢复活动栏图标: \(savedIcon)")
            }
            pluginVM.activePanelIcon = savedIcon
        }

        // 恢复侧边栏 Tab
        if let savedTabId = store.loadSelectedAgentSidebarTabId() {
            if LayoutPlugin.verbose {
                LayoutPlugin.logger.info("\(LayoutPlugin.t)恢复侧边栏 Tab: \(savedTabId)")
            }
            layoutVM.restoreFromPlugin(tabId: savedTabId)
        }

        // 恢复 Detail 视图
        if let savedDetailId = store.loadSelectedAgentDetailId() {
            if LayoutPlugin.verbose {
                LayoutPlugin.logger.info("\(LayoutPlugin.t)恢复 Detail 视图: \(savedDetailId)")
            }
            layoutVM.restoreFromPlugin(detailId: savedDetailId)
        }

        // 恢复分栏比例
        let savedRatios = store.loadLayoutRatios()
        if !savedRatios.isEmpty {
            if LayoutPlugin.verbose {
                LayoutPlugin.logger.info("\(LayoutPlugin.t)恢复分栏比例: \(savedRatios.count) 项")
            }
            layoutVM.restoreFromPlugin(ratios: savedRatios)
        }
    }

    // MARK: - Observe

    /// 开始观察 PluginVM 和 LayoutVM 的变化
    private func startObserving() {
        guard cancellables.isEmpty else { return }

        // 观察 activePanelIcon（不在视图层级中直接绑定，用 Combine）
        pluginVM.$activePanelIcon
            .dropFirst()
            .sink { newValue in
                guard hasRestored else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)活动栏图标变更: \(newValue ?? "nil")")
                }
                LayoutPluginLocalStore.shared.saveActivePanelIcon(newValue)
            }
            .store(in: &cancellables)

        // 观察 layoutRatios（字典变化）
        layoutVM.$layoutRatios
            .dropFirst()
            .sink { newRatios in
                guard hasRestored else { return }
                LayoutPluginLocalStore.shared.saveLayoutRatios(newRatios)
            }
            .store(in: &cancellables)
    }
}
