import Foundation
import SwiftUI
import os

private enum LegacyLayoutTabID {
    static let gitCommitHistory = "GitCommitHistory"
    static let gitPlugin = "GitPlugin"
}

/// 布局 ViewModel - 负责管理界面布局相关的状态（纯内存状态）
///
/// 包括 Agent 模式侧边栏 Tab、Detail 视图、分栏宽度比例等。
///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有，通过 `.environmentObject()` 注入。nView 通过 `@EnvironmentObject var layoutVM: WindowLayoutVM` 访问。
/// 持久化由 LayoutPlugin 插件负责，WindowLayoutVM 不直接读写磁盘。
///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var layoutVM: WindowLayoutVM` 访问。
@MainActor
final class WindowLayoutVM: ObservableObject, SuperLog {
    
    nonisolated static let emoji = "🖥️"
    nonisolated static let verbose: Bool = true
    
    // MARK: - Published Properties
    
    /// 底部面板是否可见
    @Published var bottomPanelVisible: Bool = true
    
    /// 内容面板是否可见
    @Published var contentPanelVisible: Bool = true
    
    /// 编辑器区域是否可见（包含 PanelContent 和 PanelBottom）
    @Published var editorVisible: Bool = true
    
    /// Rail 区域是否可见（位于活动栏与面板内容区之间的辅助栏）
    @Published var railVisible: Bool = true

    /// 右侧栏是否可见（Chat 等面板的右侧区域）
    @Published var rightSidebarVisible: Bool = true

    /// 当前激活的 ActivityBar 图标（SF Symbol 名称）
    ///
    /// 窗口级状态：每个窗口可以激活不同的面板。
    /// 点击 ActivityBar 图标时更新，驱动面板内容区切换。
    /// 持久化由 LayoutPlugin 负责。
    @Published var activeViewContainerIcon: String?

    /// 当前选中的 Agent 模式侧边栏 Tab ID
    @Published var selectedAgentSidebarTabId: String = ""
    
    /// 当前选中的 Agent 模式 Detail 视图 ID（中间栏）
    @Published var selectedAgentDetailId: String = ""
    
    /// 分栏布局宽度比例缓存
    ///
    /// Key: storageKey（如 "Split.Panel.xxx"），Value: 比例（0.0~1.0）
    /// 由 SplitViewPersistence 组件更新，LayoutPlugin 负责持久化。
    @Published var layoutRatios: [String: Double] = [:]

    // MARK: - Initialization
    
    init() {
        // 不再从磁盘恢复，由 LayoutPlugin 在 onAppear 时恢复
    }
    
    // MARK: - Agent Sidebar Tab
    
    /// 设置当前选中的 Agent 模式侧边栏 Tab
    /// - Parameters:
    ///   - tabId: 标签 ID
    ///   - reason: 切换原因，用于日志追踪
    func selectAgentSidebarTab(_ tabId: String, reason: String) {
        let old = selectedAgentSidebarTabId
        guard tabId != old else { return }
        if Self.verbose { AppLogger.layout.info("\(Self.t)Sidebar tab: \(old) → \(tabId), reason: \(reason)") }
        selectedAgentSidebarTabId = tabId
    }
    
    /// 从可用标签中恢复选中的侧边栏标签
    /// - Parameter availableTabIds: 当前可用的标签 ID 列表
    func restoreSelectedTab(from availableTabIds: [String]) {
        guard !availableTabIds.isEmpty else {
            guard !selectedAgentSidebarTabId.isEmpty else { return }
            if Self.verbose { AppLogger.layout.debug("\(Self.t)restoreSelectedTab: 无可用标签，清空选中") }
            selectedAgentSidebarTabId = ""
            return
        }
        
        if selectedAgentSidebarTabId.isEmpty || !availableTabIds.contains(selectedAgentSidebarTabId) {
            let fallback = availableTabIds[0]
            if Self.verbose { AppLogger.layout.info("\(Self.t)restoreSelectedTab: 回退到首个可用标签 \(fallback)") }
            selectedAgentSidebarTabId = fallback
        } else {
            let current = selectedAgentSidebarTabId
            if Self.verbose { AppLogger.layout.debug("\(Self.t)restoreSelectedTab: 当前选中 \(current) 仍有效") }
        }
    }
    
    // MARK: - Agent Detail View
    
    /// 设置当前选中的 Agent 模式 Detail 视图 ID
    /// - Parameter detailId: Detail 视图 ID
    func selectAgentDetail(_ detailId: String) {
        let old = selectedAgentDetailId
        guard detailId != old else { return }
        if Self.verbose { AppLogger.layout.info("\(Self.t)Detail: \(old) → \(detailId)") }
        selectedAgentDetailId = detailId
    }
    
    /// 从可用 Detail 列表中恢复选中的 Detail 视图
    /// - Parameter availableDetailIds: 当前可用的 Detail ID 列表
    func restoreSelectedDetail(from availableDetailIds: [String]) {
        guard !availableDetailIds.isEmpty else {
            guard !selectedAgentDetailId.isEmpty else { return }
            if Self.verbose { AppLogger.layout.debug("\(Self.t)restoreSelectedDetail: 无可用 Detail，清空选中") }
            selectedAgentDetailId = ""
            return
        }
        
        if selectedAgentDetailId.isEmpty || !availableDetailIds.contains(selectedAgentDetailId) {
            let fallback = availableDetailIds[0]
            if Self.verbose { AppLogger.layout.info("\(Self.t)restoreSelectedDetail: 回退到首个可用 Detail \(fallback)") }
            selectedAgentDetailId = fallback
        } else {
            let current = selectedAgentDetailId
            if Self.verbose { AppLogger.layout.debug("\(Self.t)restoreSelectedDetail: 当前选中 \(current) 仍有效") }
        }
    }
    
    /// 清除选中的标签（当没有可用标签时）
    func clearSelectedTab() {
        guard !selectedAgentSidebarTabId.isEmpty else { return }
        if Self.verbose { AppLogger.layout.info("\(Self.t)清除侧边栏标签选中") }
        selectedAgentSidebarTabId = ""
    }
    
    /// 清除选中的 Detail（当没有可用时）
    func clearSelectedDetail() {
        guard !selectedAgentDetailId.isEmpty else { return }
        if Self.verbose { AppLogger.layout.info("\(Self.t)清除 Detail 视图选中") }
        selectedAgentDetailId = ""
    }
    
    // MARK: - Plugin Restore
    
    /// 由 LayoutPlugin 调用，从本地存储恢复视图容器图标
    func restoreFromPlugin(activeViewContainerIcon: String?) {
        guard self.activeViewContainerIcon != activeViewContainerIcon else { return }
        self.activeViewContainerIcon = activeViewContainerIcon
    }

    /// 由 LayoutPlugin 调用，从本地存储恢复侧边栏 Tab ID
    func restoreFromPlugin(tabId: String) {
        let normalizedTabId = tabId == LegacyLayoutTabID.gitCommitHistory ? LegacyLayoutTabID.gitPlugin : tabId
        guard selectedAgentSidebarTabId != normalizedTabId else { return }
        selectedAgentSidebarTabId = normalizedTabId
    }
    
    /// 由 LayoutPlugin 调用，从本地存储恢复 Detail 视图 ID
    func restoreFromPlugin(detailId: String) {
        guard selectedAgentDetailId != detailId else { return }
        selectedAgentDetailId = detailId
    }
    
    /// 由 LayoutPlugin 调用，从本地存储恢复分栏比例
    func restoreFromPlugin(ratios: [String: Double]) {
        guard layoutRatios != ratios else { return }
        layoutRatios = ratios
    }

    /// 由 LayoutPlugin 调用，从本地存储恢复底部面板可见性
    func restoreFromPlugin(bottomPanelVisible: Bool) {
        guard self.bottomPanelVisible != bottomPanelVisible else { return }
        self.bottomPanelVisible = bottomPanelVisible
    }

    /// 由 LayoutPlugin 调用，从本地存储恢复内容面板可见性
    func restoreFromPlugin(contentPanelVisible: Bool) {
        guard self.contentPanelVisible != contentPanelVisible else { return }
        self.contentPanelVisible = contentPanelVisible
    }

    /// 由 LayoutPlugin 调用，从本地存储恢复编辑器区域可见性
    func restoreFromPlugin(editorVisible: Bool) {
        guard self.editorVisible != editorVisible else { return }
        self.editorVisible = editorVisible
    }

    /// 由 LayoutPlugin 调用，从本地存储恢复 Rail 区域可见性
    func restoreFromPlugin(railVisible: Bool) {
        guard self.railVisible != railVisible else { return }
        self.railVisible = railVisible
    }

    /// 由 LayoutPlugin 调用，从本地存储恢复右侧栏可见性
    func restoreFromPlugin(rightSidebarVisible: Bool) {
        guard self.rightSidebarVisible != rightSidebarVisible else { return }
        self.rightSidebarVisible = rightSidebarVisible
    }

    /// 更新指定分栏的宽度比例。
    ///
    /// 不直接修改 `layoutRatios[key]`，避免对字典的原地变更绕过 `@Published`
    /// 的发布链路，导致插件观察不到变化。
    func setLayoutRatio(_ ratio: Double, forKey key: String) {
        let oldValue = layoutRatios[key]
        guard oldValue != ratio else { return }

        var next = layoutRatios
        next[key] = ratio
        if Self.verbose {
            AppLogger.layout.info("\(Self.t)Layout ratio[\(key)] = \(ratio)")
        }
        layoutRatios = next
    }
}
