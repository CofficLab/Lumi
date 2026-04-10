import Foundation
import SwiftUI

/// 布局 ViewModel - 负责管理界面布局相关的状态
/// 包括中间栏（Agent 模式侧边栏）的标签选择状态
@MainActor
final class LayoutVM: ObservableObject {
    
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
        }
        // 从持久化存储恢复上次选中的 detail ID
        if let savedDetailId = AppSettingStore.loadSelectedAgentDetailId() {
            self.selectedAgentDetailId = savedDetailId
        }
    }
    
    // MARK: - Agent Sidebar Tab
    
    /// 设置当前选中的 Agent 模式侧边栏 Tab
    /// - Parameter tabId: 标签 ID
    func selectAgentSidebarTab(_ tabId: String) {
        guard tabId != selectedAgentSidebarTabId else { return }
        selectedAgentSidebarTabId = tabId
        AppSettingStore.saveSelectedAgentSidebarTabId(tabId)
    }
    
    /// 从持久化存储恢复上次选中的侧边栏标签
    /// - Parameter availableTabIds: 当前可用的标签 ID 列表
    func restoreSelectedTab(from availableTabIds: [String]) {
        guard !availableTabIds.isEmpty else {
            selectedAgentSidebarTabId = ""
            return
        }
        
        // 如果当前没有选中标签，或选中的标签不在可用列表中
        if selectedAgentSidebarTabId.isEmpty || !availableTabIds.contains(selectedAgentSidebarTabId) {
            // 尝试从持久化存储恢复
            if let savedTabId = AppSettingStore.loadSelectedAgentSidebarTabId(),
               availableTabIds.contains(savedTabId) {
                selectedAgentSidebarTabId = savedTabId
            } else {
                // 使用第一个可用标签作为默认值
                selectedAgentSidebarTabId = availableTabIds[0]
                AppSettingStore.saveSelectedAgentSidebarTabId(selectedAgentSidebarTabId)
            }
        }
    }
    
    // MARK: - Agent Detail View
    
    /// 设置当前选中的 Agent 模式 Detail 视图 ID
    /// - Parameter detailId: Detail 视图 ID
    func selectAgentDetail(_ detailId: String) {
        guard detailId != selectedAgentDetailId else { return }
        selectedAgentDetailId = detailId
        AppSettingStore.saveSelectedAgentDetailId(detailId)
    }
    
    /// 从持久化存储恢复上次选中的 Detail 视图
    /// - Parameter availableDetailIds: 当前可用的 Detail ID 列表
    func restoreSelectedDetail(from availableDetailIds: [String]) {
        guard !availableDetailIds.isEmpty else {
            selectedAgentDetailId = ""
            return
        }
        
        // 如果当前没有选中，或选中的不在可用列表中
        if selectedAgentDetailId.isEmpty || !availableDetailIds.contains(selectedAgentDetailId) {
            // 尝试从持久化存储恢复
            if let savedDetailId = AppSettingStore.loadSelectedAgentDetailId(),
               availableDetailIds.contains(savedDetailId) {
                selectedAgentDetailId = savedDetailId
            } else {
                // 使用第一个可用作为默认值
                selectedAgentDetailId = availableDetailIds[0]
                AppSettingStore.saveSelectedAgentDetailId(selectedAgentDetailId)
            }
        }
    }
    
    /// 清除选中的标签（当没有可用标签时）
    func clearSelectedTab() {
        selectedAgentSidebarTabId = ""
    }
    
    /// 清除选中的 Detail（当没有可用时）
    func clearSelectedDetail() {
        selectedAgentDetailId = ""
    }
}
