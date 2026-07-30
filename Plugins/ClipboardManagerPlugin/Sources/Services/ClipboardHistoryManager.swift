import Foundation
import SuperLogKit
import SwiftData

/// 剪贴板历史管理器
///
/// 负责历史数据的增删改查和数据清理。
/// 使用 SwiftData 持久化到 `ClipboardManagerRuntime.databaseDirectory()/ClipboardManager/history.sqlite`
public actor ClipboardHistoryManager: SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true
    static let maxFetchLimit = 5_000
    
    // MARK: - Singleton
    
    public static let shared = ClipboardHistoryManager()
    
    // MARK: - Properties
    
    private let container: ModelContainer
    
    /// 最大记录数（不包括固定项）
    private let maxRecords = 500
    
    /// 数据保留期限（秒）- 默认保留 30 天
    private let retentionPeriod: TimeInterval = 30 * 24 * 60 * 60
    
    // MARK: - Initialization
    
    private init() {
        self.container = Self.makeContainer(databaseDirectory: ClipboardManagerRuntime.databaseDirectory())
    }

    init(databaseDirectory: URL) {
        self.container = Self.makeContainer(databaseDirectory: databaseDirectory)
    }

    static func makeContainer(databaseDirectory: URL) -> ModelContainer {
        let schema = Schema([ClipboardHistoryItem.self])
        let dbDir = databaseDirectory.appendingPathComponent("ClipboardManager", isDirectory: true)
        let dbURL = dbDir.appendingPathComponent("history.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            if ClipboardManagerPlugin.verbose {
                ClipboardManagerPlugin.logger.error("\(Self.t)❌ 创建剪贴板数据库目录失败：\(error.localizedDescription)")
            }
        }

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if ClipboardManagerPlugin.verbose {
                ClipboardManagerPlugin.logger.error("\(Self.t)❌ 打开剪贴板历史数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if ClipboardManagerPlugin.verbose {
                ClipboardManagerPlugin.logger.error("\(Self.t)❌ 重建剪贴板历史数据库失败，使用临时内存存储：\(error.localizedDescription)")
            }
            return makeInMemoryContainer(schema: schema)
        }
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            preconditionFailure("Could not create in-memory ClipboardManager ModelContainer: \(error)")
        }
    }

    private static func quarantinePersistentStore(at dbURL: URL) {
        let fileManager = FileManager.default
        let storeURLs = [
            dbURL,
            URL(fileURLWithPath: dbURL.path + "-shm"),
            URL(fileURLWithPath: dbURL.path + "-wal")
        ]

        for url in storeURLs where fileManager.fileExists(atPath: url.path) {
            quarantineFile(at: url)
        }
    }

    private static func quarantineFileIfItBlocksDirectory(at url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return
        }

        quarantineFile(at: url)
    }

    private static func quarantineFile(at url: URL) {
        let destination = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".corrupt-\(Int(Date().timeIntervalSince1970))")
        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            if ClipboardManagerPlugin.verbose {
                ClipboardManagerPlugin.logger.error("\(Self.t)❌ 隔离剪贴板数据库文件失败：\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public API
    
    /// 添加剪贴板项
    @discardableResult
    public func add(_ item: ClipboardHistoryItem) async -> Bool {
        let context = ModelContext(container)
        
        context.insert(item)
        
        // 定期清理过期数据（每 50 条数据检查一次）
        let descriptor = FetchDescriptor<ClipboardHistoryItem>()
        if let count = try? context.fetchCount(descriptor), count > maxRecords + 100 {
            await cleanupOldData(context: context)
        }
        
        let saved = save(context, operation: "保存剪贴板项")
        
        if saved, Self.verbose {
            if ClipboardManagerPlugin.verbose {
                            ClipboardManagerPlugin.logger.info("\(Self.t)➕ 添加剪贴板项：\(item.content.prefix(50))...")
            }
        }
        return saved
    }
    
    /// 从 ClipboardItem 添加
    @discardableResult
    public func add(_ item: ClipboardItem) async -> Bool {
        let historyItem = ClipboardHistoryItem(from: item)
        return await add(historyItem)
    }
    
    /// 批量添加（用于迁移）
    @discardableResult
    public func addBatch(_ items: [ClipboardHistoryItem]) async -> Bool {
        let context = ModelContext(container)
        
        for item in items {
            context.insert(item)
        }
        
        let saved = save(context, operation: "批量保存剪贴板项")
        
        if saved, Self.verbose {
            if ClipboardManagerPlugin.verbose {
                            ClipboardManagerPlugin.logger.info("\(Self.t)📦 批量添加 \(items.count) 个剪贴板项")
            }
        }
        return saved
    }
    
    /// 查询所有项（按时间倒序）
    public func getAll(limit: Int = 1000) async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        let limit = Self.normalizedFetchLimit(limit)
        
        var descriptor = FetchDescriptor<ClipboardHistoryItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            if ClipboardManagerPlugin.verbose {
                            ClipboardManagerPlugin.logger.error("\(Self.t)❌ 查询失败：\(error.localizedDescription)")
            }
            return []
        }
    }
    
    /// 查询指定时间范围内的数据
    public func query(from startTime: Date, to endTime: Date) async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: ClipboardHistoryItem.predicate(from: startTime, to: endTime),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        
        do {
            return try context.fetch(descriptor)
        } catch {
            if ClipboardManagerPlugin.verbose {
                            ClipboardManagerPlugin.logger.error("\(Self.t)❌ 查询失败：\(error.localizedDescription)")
            }
            return []
        }
    }
    
    /// 搜索
    public func search(keyword: String, limit: Int = 100) async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        let limit = Self.normalizedFetchLimit(limit)
        
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
    public func getPinned() async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>(
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
    public func getLatest(limit: Int = 100) async -> [ClipboardHistoryItem] {
        let context = ModelContext(container)
        let limit = Self.normalizedFetchLimit(limit)
        
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
    @discardableResult
    public func updatePinStatus(id: UUID, isPinned: Bool) async -> Bool {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: #Predicate<ClipboardHistoryItem> { $0.id == id }
        )
        
        if let item = try? context.fetch(descriptor).first {
            item.isPinned = isPinned
            let saved = save(context, operation: "更新剪贴板固定状态")
            
            if saved, Self.verbose {
                if ClipboardManagerPlugin.verbose {
                                    ClipboardManagerPlugin.logger.info("\(Self.t)📌 更新固定状态：\(id) -> \(isPinned)")
                }
            }
            return saved
        }
        return false
    }
    
    /// 删除指定项
    @discardableResult
    public func delete(id: UUID) async -> Bool {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: #Predicate<ClipboardHistoryItem> { $0.id == id }
        )
        
        if let item = try? context.fetch(descriptor).first {
            context.delete(item)
            let saved = save(context, operation: "删除剪贴板项")
            
            if saved, Self.verbose {
                if ClipboardManagerPlugin.verbose {
                                    ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 已删除：\(id)")
                }
            }
            return saved
        }
        return false
    }
    
    /// 批量删除
    @discardableResult
    public func delete(ids: [UUID]) async -> Bool {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>(
            predicate: #Predicate<ClipboardHistoryItem> { ids.contains($0.id) }
        )
        
        if let items = try? context.fetch(descriptor) {
            for item in items {
                context.delete(item)
            }
            let saved = save(context, operation: "批量删除剪贴板项")
            
            if saved, Self.verbose {
                if ClipboardManagerPlugin.verbose {
                                    ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 批量删除 \(ids.count) 项")
                }
            }
            return saved
        }
        return false
    }
    
    /// 清空所有历史记录（保留固定项可选）
    @discardableResult
    public func clearAll(keepPinned: Bool = false) async -> Bool {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<ClipboardHistoryItem>()
        guard let allItems = try? context.fetch(descriptor) else { return false }
        
        let itemsToDelete: [ClipboardHistoryItem]
        if keepPinned {
            itemsToDelete = allItems.filter { !$0.isPinned }
        } else {
            itemsToDelete = allItems
        }
        
        for item in itemsToDelete {
            context.delete(item)
        }
        
        let saved = save(context, operation: "清空剪贴板历史")
        
        if saved, Self.verbose {
            if ClipboardManagerPlugin.verbose {
                            ClipboardManagerPlugin.logger.info("\(Self.t)🗑️ 已清空 \(itemsToDelete.count) 项历史记录")
            }
        }
        return saved
    }
    
    /// 清理过期数据
    public func cleanup() async {
        let context = ModelContext(container)
        await cleanupOldData(context: context)
    }
    
    /// 从 JSON 迁移数据
    @discardableResult
    public func migrateFromJSON(items: [ClipboardItem]) async -> Bool {
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
        
        let saved = save(context, operation: "迁移剪贴板历史")
        
        if saved, Self.verbose {
            if ClipboardManagerPlugin.verbose {
                            ClipboardManagerPlugin.logger.info("\(Self.t)✅ 迁移完成：\(items.count) 项")
            }
        }
        return saved
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
        
        let saved = save(context, operation: "清理过期剪贴板历史")
        
        if saved, Self.verbose && !oldItems.isEmpty {
            if ClipboardManagerPlugin.verbose {
                            ClipboardManagerPlugin.logger.info("\(Self.t)🧹 清理了 \(oldItems.count) 条过期记录")
            }
        }
    }

    private func save(_ context: ModelContext, operation: StaticString) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            if ClipboardManagerPlugin.verbose {
                ClipboardManagerPlugin.logger.error("\(Self.t)❌ \(operation)失败：\(error.localizedDescription)")
            }
            return false
        }
    }

    static func normalizedFetchLimit(_ limit: Int) -> Int {
        min(max(limit, 1), maxFetchLimit)
    }
}
