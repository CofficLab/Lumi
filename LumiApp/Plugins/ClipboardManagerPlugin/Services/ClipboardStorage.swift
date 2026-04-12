import Foundation
import MagicKit

/// 剪贴板存储
///
/// 使用 ClipboardHistoryManager (SwiftData) 进行持久化存储
/// 存储位置：AppConfig.getDBFolderURL()/ClipboardManager/history.sqlite
actor ClipboardStorage: SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false
    
    static let shared = ClipboardStorage()
    
    private let historyManager = ClipboardHistoryManager.shared
    private let maxRecentItems = 500
    
    private init() {
        // 启动时清理过期数据
        Task {
            await historyManager.cleanup()
        }
    }
    
    // MARK: - Public API
    
    /// 添加剪贴板项
    func add(item: ClipboardItem) async {
        // 去重：如果与第一项内容相同，则更新（或忽略）
        let recentItems = await historyManager.getLatest(limit: 1)
        if let first = recentItems.first,
           first.content == item.content && first.type == item.type.rawValue {
            // 如果是固定项则保留，否则移除旧的
            if !first.isPinned {
                await historyManager.delete(id: first.id)
            }
        }
        
        let historyItem = ClipboardHistoryItem(from: item)
        await historyManager.add(historyItem)
        
        // 检查是否需要清理
        await cleanupIfNeeded()
        
        if Self.verbose {
            ClipboardManagerPlugin.logger.info("\(Self.t)➕ 已添加剪贴板项：\(item.content.prefix(50))...")
        }
    }
    
    /// 获取所有项
    func getItems() async -> [ClipboardHistoryItem] {
        return await historyManager.getAll(limit: maxRecentItems)
    }
    
    /// 获取最新的 N 项
    func getLatest(limit: Int = 100) async -> [ClipboardHistoryItem] {
        return await historyManager.getLatest(limit: limit)
    }
    
    /// 获取固定项
    func getPinned() async -> [ClipboardHistoryItem] {
        return await historyManager.getPinned()
    }
    
    /// 清空历史记录
    func clear(keepPinned: Bool = true) async {
        await historyManager.clearAll(keepPinned: keepPinned)
        if Self.verbose {
            ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 已清空剪贴板历史")
        }
    }
    
    /// 切换固定状态
    func togglePin(id: UUID) async {
        let items = await historyManager.getAll(limit: 1000)
        if let item = items.first(where: { $0.id == id }) {
            await historyManager.updatePinStatus(id: id, isPinned: !item.isPinned)
            if Self.verbose {
                ClipboardManagerPlugin.logger.info("\(Self.t)📌 已切换固定状态：\(id)")
            }
        }
    }
    
    /// 删除指定项
    func delete(id: UUID) async {
        let item = await getItemById(id: id)
        await historyManager.delete(id: id)
        if Self.verbose {
            let wasPinned = item?.isPinned ?? false
            ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 已删除剪贴板项：\(id)\(wasPinned ? " (已固定)" : "")")
        }
    }
    
    /// 批量删除
    func delete(ids: [UUID]) async {
        await historyManager.delete(ids: ids)
        if Self.verbose {
            ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 批量删除 \(ids.count) 项")
        }
    }
    
    /// 搜索
    func search(keyword: String) async -> [ClipboardHistoryItem] {
        return await historyManager.search(keyword: keyword, limit: 100)
    }
    
    /// 查询时间范围
    func query(from startTime: Date, to endTime: Date) async -> [ClipboardHistoryItem] {
        return await historyManager.query(from: startTime, to: endTime)
    }
    
    /// 从旧 JSON 格式迁移数据
    func migrateFromJSON(items: [ClipboardItem]) async {
        await historyManager.migrateFromJSON(items: items)
    }
    
    // MARK: - Private Helpers
    
    /// 获取单个项
    private func getItemById(id: UUID) async -> ClipboardHistoryItem? {
        let items = await historyManager.getAll(limit: 1000)
        return items.first { $0.id == id }
    }
    
    /// 清理超出限制的非固定项
    private func cleanupIfNeeded() async {
        let allItems = await historyManager.getAll(limit: maxRecentItems + 100)
        let nonPinnedItems = allItems.filter { !$0.isPinned }
        
        if nonPinnedItems.count > maxRecentItems {
            let itemsToDelete = nonPinnedItems.suffix(from: maxRecentItems).map { $0.id }
            await historyManager.delete(ids: Array(itemsToDelete))
            
            if Self.verbose {
                ClipboardManagerPlugin.logger.info("\(Self.t)🧹 清理了 \(itemsToDelete.count) 项超出限制的历史")
            }
        }
    }
}
