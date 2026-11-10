import Foundation
import LumiLoggingKit
import os

/// 剪贴板存储
///
/// 使用 ClipboardHistoryManager (SwiftData) 进行持久化存储
/// 存储位置：`<dataRoot>/<pluginID>/history.sqlite`
public actor ClipboardStorage: SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = false
    public static let logger = ClipboardManagerPluginSupport.logger

    public static let shared = ClipboardStorage()

    private let historyManager: ClipboardHistoryManager
    /// 每次清理时读取最新的历史上限，用户改设置后无需重启插件。
    private let historyLimitProvider: @Sendable () -> Int

    /// 注入历史管理器。
    ///
    /// 生产环境使用共享单例；单元测试注入指向临时目录的实例，
    /// 避免污染用户的真实剪贴板数据库。
    init(
        historyManager: ClipboardHistoryManager = ClipboardHistoryManager.shared,
        historyLimitProvider: @escaping @Sendable () -> Int = { ClipboardSettings.historyLimit }
    ) {
        self.historyManager = historyManager
        self.historyLimitProvider = historyLimitProvider
        // 启动时清理过期数据
        Task {
            await historyManager.cleanup()
        }
    }

    // MARK: - Public API

    /// 添加剪贴板项
    public func add(item: ClipboardItem) async {
        // 去重：如果与第一项内容相同，则更新（或忽略）。
        // 富文本负载也算身份的一部分：纯文本相同但格式不同时应各留一条。
        let recentItems = await historyManager.getLatest(limit: 1)
        if let first = recentItems.first, isDuplicate(item, of: first) {
            // 如果是固定项则保留，否则移除旧的
            if !first.isPinned {
                await historyManager.delete(id: first.id)
                // 图片内容相同但每次采集都会生成新路径；旧文件已无条目引用，
                // 删除它避免同一张图片在磁盘上不断累积。
                if first.type == ClipboardItemType.image.rawValue,
                   first.content != item.content {
                    try? FileManager.default.removeItem(atPath: first.content)
                }
            }
        }

        let historyItem = ClipboardHistoryItem(from: item)
        await historyManager.add(historyItem)

        // 检查是否需要清理
        await cleanupIfNeeded()

        if Self.verbose {
            Self.logger.info("\(Self.t)➕ 已添加剪贴板项：\(item.content.prefix(50))...")
        }
    }

    /// 判断新条目是否与最近一条重复。
    ///
    /// 图片每次采集都会写入随机文件名，路径不能作为身份；按文件内容比较，
    /// 否则同一张图片反复复制会不断新增记录。
    private nonisolated func isDuplicate(_ item: ClipboardItem, of first: ClipboardHistoryItem) -> Bool {
        guard first.type == item.type.rawValue,
              first.richTextRTF == item.richTextRTF,
              first.richTextHTML == item.richTextHTML else {
            return false
        }
        guard item.type == .image else {
            return first.content == item.content
        }
        // 路径相同代表同一次采集；否则比较落盘内容。旧文件缺失时视为不同。
        return first.content != item.content
            && FileManager.default.contentsEqual(atPath: item.content, andPath: first.content)
    }

    /// 获取所有项
    public func getItems() async -> [ClipboardHistoryItem] {
        return await historyManager.getAll(limit: ClipboardHistoryManager.maxFetchLimit)
    }

    /// 获取最新的 N 项
    public func getLatest(limit: Int = 100) async -> [ClipboardHistoryItem] {
        return await historyManager.getLatest(limit: limit)
    }

    /// 获取固定项
    public func getPinned() async -> [ClipboardHistoryItem] {
        return await historyManager.getPinned()
    }

    /// 清空历史记录
    public func clear(keepPinned: Bool = true) async {
        await historyManager.clearAll(keepPinned: keepPinned)
        if Self.verbose {
            if ClipboardManagerPluginSupport.verbose {
                ClipboardManagerPluginSupport.logger.info("\(Self.t)🗑️ 已清空剪贴板历史")
            }
        }
    }

    /// 切换固定状态
    public func togglePin(id: UUID) async {
        let items = await historyManager.getAll(limit: 1000)
        if let item = items.first(where: { $0.id == id }) {
            await historyManager.updatePinStatus(id: id, isPinned: !item.isPinned)
            if Self.verbose {
                if ClipboardManagerPluginSupport.verbose {
                    ClipboardManagerPluginSupport.logger.info("\(Self.t)📌 已切换固定状态：\(id)")
                }
            }
        }
    }

    /// 删除指定项
    public func delete(id: UUID) async {
        let item = await getItemById(id: id)
        await historyManager.delete(id: id)
        if Self.verbose {
            let wasPinned = item?.isPinned ?? false
            if ClipboardManagerPluginSupport.verbose {
                ClipboardManagerPluginSupport.logger.info("\(Self.t)🗑️ 已删除剪贴板项：\(id)\(wasPinned ? " (已固定)" : "")")
            }
        }
    }

    /// 批量删除
    public func delete(ids: [UUID]) async {
        await historyManager.delete(ids: ids)
        if Self.verbose {
            if ClipboardManagerPluginSupport.verbose {
                ClipboardManagerPluginSupport.logger.info("\(Self.t)🗑️ 批量删除 \(ids.count) 项")
            }
        }
    }

    /// 搜索
    public func search(keyword: String) async -> [ClipboardHistoryItem] {
        return await historyManager.search(keyword: keyword, limit: 100)
    }

    /// 查询时间范围
    public func query(from startTime: Date, to endTime: Date) async -> [ClipboardHistoryItem] {
        return await historyManager.query(from: startTime, to: endTime)
    }

    /// 从旧 JSON 格式迁移数据
    public func migrateFromJSON(items: [ClipboardItem]) async {
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
        let configuredLimit = historyLimitProvider()
        // “Unlimited” 时不清理；否则按用户设置的上限裁剪。
        guard configuredLimit != ClipboardSettings.unlimitedHistorySize else { return }
        let limit = max(1, min(configuredLimit, ClipboardHistoryManager.maxFetchLimit))
        let allItems = await historyManager.getAll(limit: limit + 100)
        let nonPinnedItems = allItems.filter { !$0.isPinned }

        if nonPinnedItems.count > limit {
            let itemsToDelete = nonPinnedItems.suffix(from: limit).map { $0.id }
            await historyManager.delete(ids: Array(itemsToDelete))

            if Self.verbose {
                if ClipboardManagerPluginSupport.verbose {
                    ClipboardManagerPluginSupport.logger.info("\(Self.t)🧹 清理了 \(itemsToDelete.count) 项超出限制的历史")
                }
            }
        }
    }
}
