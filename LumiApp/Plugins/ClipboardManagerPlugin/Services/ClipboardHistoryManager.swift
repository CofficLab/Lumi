import Foundation
import SwiftData
import MagicKit

/// 剪贴板历史管理器
///
/// 负责历史数据的增删改查和数据清理。
/// 使用 SwiftData 持久化到 `AppConfig.getDBFolderURL()/ClipboardManager/history.sqlite`
actor ClipboardHistoryManager: SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false
    
    // MARK: - Singleton
    
    static let shared = ClipboardHistoryManager()
    
    // MARK: - Properties
    
    private let container: ModelContainer
    
    /// 最大记录数（不包括固定项）
    private let maxRecords = 500
    
    /// 数据保留期限（秒）- 默认保留 30 天
    private let retentionPeriod: TimeInterval = 30 * 24 * 60 * 60
    
    // MARK: - Initialization
    
    private init() {
        // 定义 Schema
        let schema = Schema([ClipboardHistoryItem.self])
        
        // 数据库路径
        let dbDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("ClipboardManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("history.sqlite")
        
        // 配置 ModelContainer
        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ClipboardManager ModelContainer: \(error)")
        }
    }
    
    // MARK: - Public API
    
    /// 添加剪贴板项
    func add(_ item: ClipboardHistoryItem) async {
        let context = ModelContext(container)
        
        context.insert(item)
        
        // 定期清理过期数据（每 50 条数据检查一次）
        let descriptor = FetchDescriptor<ClipboardHistoryItem>()
        if let count = try? context.fetchCount(descriptor), count > maxRecords + 100 {
            await cleanupOldData(context: context)
        }
        
        try? context.save()
        
        if Self.verbose {
            ClipboardManagerPlugin.logger.info("\(Self.t)➕ 添加剪贴板项：\(item.content.prefix(50))...")
        }
    }
    
    /// 从 ClipboardItem 添加
    func add(_ item: ClipboardItem) async {
        let historyItem = ClipboardHistoryItem(from: item)
        await add(historyItem)
    }
    
    /// 批量添加（用于迁移）
    func addBatch(_ items: [ClipboardHistoryItem]) async {
        let context = ModelContext(container)
        
        for item in items {
            context.insert(item)
        }
        
        try? context.save()
        
        if Self.verbose {
            ClipboardManagerPlugin.logger.info("\(Self.t)📦 批量添加 \(items.count) 个剪贴板项")
        }
    }
    
    /// 查询所有项（按时间倒序）
    func getAll(limit: Int = 1000) async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<ClipboardHistoryItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            ClipboardManagerPlugin.logger.error("\(Self.t)❌ 查询失败：\(error.localizedDescription)")
            return []
        }
    }
    
    /// 查询指定时间范围内的数据
    func query(from startTime: Date, to endTime: Date) async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: ClipboardHistoryItem.predicate(from: startTime, to: endTime),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        
        do {
            return try context.fetch(descriptor)
        } catch {
            ClipboardManagerPlugin.logger.error("\(Self.t)❌ 查询失败：\(error.localizedDescription)")
            return []
        }
    }
    
    /// 搜索
    func search(keyword: String, limit: Int = 100) async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: ClipboardHistoryItem.searchPredicate(for: keyword),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }
    
    /// 获取固定项
    func getPinned() async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: ClipboardHistoryItem.pinnedPredicate(),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }
    
    /// 获取最新 N 条记录
    func getLatest(limit: Int = 100) async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<ClipboardHistoryItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }
    
    /// 更新固定状态
    func updatePinStatus(id: UUID, isPinned: Bool) async {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: #Predicate<ClipboardHistoryItem> { $0.id == id }
        )
        
        if var item = try? context.fetch(descriptor).first {
            item.isPinned = isPinned
            try? context.save()
            
            if Self.verbose {
                ClipboardManagerPlugin.logger.info("\(Self.t)📌 更新固定状态：\(id) -> \(isPinned)")
            }
        }
    }
    
    /// 删除指定项
    func delete(id: UUID) async {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: #Predicate<ClipboardHistoryItem> { $0.id == id }
        )
        
        if let item = try? context.fetch(descriptor).first {
            context.delete(item)
            try? context.save()
            
            if Self.verbose {
                ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 已删除：\(id)")
            }
        }
    }
    
    /// 批量删除
    func delete(ids: [UUID]) async {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: #Predicate<ClipboardHistoryItem> { ids.contains($0.id) }
        )
        
        if let items = try? context.fetch(descriptor) {
            for item in items {
                context.delete(item)
            }
            try? context.save()
            
            if Self.verbose {
                ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 批量删除 \(ids.count) 项")
            }
        }
    }
    
    /// 清空所有历史记录（保留固定项可选）
    func clearAll(keepPinned: Bool = false) async {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }
        
        let itemsToDelete: [ClipboardHistoryItem]
        if keepPinned {
            itemsToDelete = allItems.filter { !$0.isPinned }
        } else {
            itemsToDelete = allItems
        }
        
        for item in itemsToDelete {
            context.delete(item)
        }
        
        try? context.save()
        
        if Self.verbose {
            ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 已清空 \(itemsToDelete.count) 项历史记录")
        }
    }
    
    /// 清理过期数据
    func cleanup() async {
        let context = ModelContext(container)
        await cleanupOldData(context: context)
    }
    
    /// 从 JSON 迁移数据
    func migrateFromJSON(items: [ClipboardItem]) async {
        let context = ModelContext(container)
        
        // 先清空现有数据
        let descriptor = FetchDescriptor<ClipboardHistoryItem>()
        if let existing = try? context.fetch(descriptor) {
            for item in existing {
                context.delete(item)
            }
        }
        
        // 导入新数据
        for item in items {
            let historyItem = ClipboardHistoryItem(from: item)
            context.insert(historyItem)
        }
        
        try? context.save()
        
        if Self.verbose {
            ClipboardManagerPlugin.logger.info("\(Self.t)✅ 迁移完成：\(items.count) 项")
        }
    }
    
    // MARK: - Private Helpers
    
    /// 清理过期数据
    private func cleanupOldData(context: ModelContext) async {
        let cutoffDate = Date().timeIntervalSince1970 - retentionPeriod
        let cutoff = Date(timeIntervalSince1970: cutoffDate)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: #Predicate<ClipboardHistoryItem> { item in
                item.timestamp < cutoff && item.isPinned == false
            }
        )
        
        guard let oldItems = try? context.fetch(descriptor) else { return }
        
        for item in oldItems {
            context.delete(item)
        }
        
        try? context.save()
        
        if Self.verbose && !oldItems.isEmpty {
            ClipboardManagerPlugin.logger.info("\(Self.t)🧹 清理了 \(oldItems.count) 条过期记录")
        }
    }
}
