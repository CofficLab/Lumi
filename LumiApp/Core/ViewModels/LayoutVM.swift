import Foundation
import SwiftUI
import os
import MagicKit

/// 布局 ViewModel - 负责管理界面布局相关的状态
/// 包括中间栏（Agent 模式侧边栏）的标签选择状态
@MainActor
final class LayoutVM: ObservableObject, SuperLog {
    
    nonisolated static let emoji = "🖥️"
    nonisolated static let verbose = false
    
    // MARK: - Published Properties
    
    /// 当前选中的 Agent 模式侧边栏 Tab ID
    @Published private(set) var selectedAgentSidebarTabId: String = ""
    
    /// 当前选中的 Agent 模式 Detail 视图 ID（中间栏）
    @Published private(set) var selectedAgentDetailId: String = ""
    
    // MARK: - Initialization
    
    init() {
        // 从持久化存储恢复上次选中的标签
        if let savedTabId = AppSettingStore.loadSelectedAgentSidebarTabId() {
            self.selectedAgentSidebarTabId = savedTabId
            AppLogger.layout.info("\(Self.t)恢复侧边栏标签: \(savedTabId)")
        }
        // 从持久化存储恢复上次选中的 detail ID
        if let savedDetailId = AppSettingStore.loadSelectedAgentDetailId() {
            self.selectedAgentDetailId = savedDetailId
            AppLogger.layout.info("\(Self.t)恢复 Detail 视图: \(savedDetailId)")
        }
    }
    
    // MARK: - Agent Sidebar Tab
    
    /// 设置当前选中的 Agent 模式侧边栏 Tab
    /// - Parameters:
    ///   - tabId: 标签 ID
    ///   - reason: 切换原因，用于日志追踪
    func selectAgentSidebarTab(_ tabId: String, reason: String) {
        let old = selectedAgentSidebarTabId
        guard tabId != old else { return }
        AppLogger.layout.info("\(Self.t)Sidebar tab: \(old) → \(tabId), reason: \(reason)")
        selectedAgentSidebarTabId = tabId
        AppSettingStore.saveSelectedAgentSidebarTabId(tabId)
    }
    
    /// 从持久化存储恢复上次选中的侧边栏标签
    /// - Parameter availableTabIds: 当前可用的标签 ID 列表
    func restoreSelectedTab(from availableTabIds: [String]) {
        guard !availableTabIds.isEmpty else {
            if Self.verbose { AppLogger.layout.debug("\(Self.t)restoreSelectedTab: 无可用标签，清空选中") }
            selectedAgentSidebarTabId = ""
            return
        }
        
        // 如果当前没有选中标签，或选中的标签不在可用列表中
        if selectedAgentSidebarTabId.isEmpty || !availableTabIds.contains(selectedAgentSidebarTabId) {
            // 尝试从持久化存储恢复
            if let savedTabId = AppSettingStore.loadSelectedAgentSidebarTabId(),
               availableTabIds.contains(savedTabId) {
                AppLogger.layout.info("\(Self.t)restoreSelectedTab: 恢复 \(savedTabId)")
                selectedAgentSidebarTabId = savedTabId
            } else {
                let fallback = availableTabIds[0]
                AppLogger.layout.info("\(Self.t)restoreSelectedTab: 回退到首个可用标签 \(fallback)")
                selectedAgentSidebarTabId = fallback
                AppSettingStore.saveSelectedAgentSidebarTabId(selectedAgentSidebarTabId)
            }
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
        AppLogger.layout.info("\(Self.t)Detail: \(old) → \(detailId)")
        selectedAgentDetailId = detailId
        AppSettingStore.saveSelectedAgentDetailId(detailId)
    }
    
    /// 从持久化存储恢复上次选中的 Detail 视图
    /// - Parameter availableDetailIds: 当前可用的 Detail ID 列表
    func restoreSelectedDetail(from availableDetailIds: [String]) {
        guard !availableDetailIds.isEmpty else {
            if Self.verbose { AppLogger.layout.debug("\(Self.t)restoreSelectedDetail: 无可用 Detail，清空选中") }
            selectedAgentDetailId = ""
            return
        }
        
        // 如果当前没有选中，或选中的不在可用列表中
        if selectedAgentDetailId.isEmpty || !availableDetailIds.contains(selectedAgentDetailId) {
            // 尝试从持久化存储恢复
            if let savedDetailId = AppSettingStore.loadSelectedAgentDetailId(),
               availableDetailIds.contains(savedDetailId) {
                AppLogger.layout.info("\(Self.t)restoreSelectedDetail: 恢复 \(savedDetailId)")
                selectedAgentDetailId = savedDetailId
            } else {
                let fallback = availableDetailIds[0]
                AppLogger.layout.info("\(Self.t)restoreSelectedDetail: 回退到首个可用 Detail \(fallback)")
                selectedAgentDetailId = fallback
                AppSettingStore.saveSelectedAgentDetailId(selectedAgentDetailId)
            }
        } else {
            let current = selectedAgentDetailId
            if Self.verbose { AppLogger.layout.debug("\(Self.t)restoreSelectedDetail: 当前选中 \(current) 仍有效") }
        }
    }
    
    /// 清除选中的标签（当没有可用标签时）
    func clearSelectedTab() {
        AppLogger.layout.info("\(Self.t)清除侧边栏标签选中")
        selectedAgentSidebarTabId = ""
    }
    
    /// 清除选中的 Detail（当没有可用时）
    func clearSelectedDetail() {
        AppLogger.layout.info("\(Self.t)清除 Detail 视图选中")
        selectedAgentDetailId = ""
    }
}
