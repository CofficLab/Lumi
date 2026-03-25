import Foundation
import SwiftData

/// 剪贴板历史记录数据模型
///
/// 使用 @Model 宏定义 SwiftData 模型，用于持久化剪贴板历史
@Model
final class ClipboardHistoryItem: @unchecked Sendable {
    /// 唯一标识符
    var id: UUID
    
    /// 时间戳
    var timestamp: Date
    
    /// 类型
    var type: String
    
    /// 内容
    var content: String
    
    /// 是否固定
    var isPinned: Bool
    
    /// 来源应用名称
    var appName: String?
    
    /// 搜索关键词（已在存储前转换为小写）
    var searchKeywords: String
    
    // MARK: - 初始化
    
    init(id: UUID = UUID(), timestamp: Date = Date(), type: String, content: String, isPinned: Bool = false, appName: String? = nil, searchKeywords: String) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.content = content
        self.isPinned = isPinned
        self.appName = appName
        // 确保搜索关键词以小写存储
        self.searchKeywords = searchKeywords.lowercased()
    }
    
    // MARK: - 转换方法
    
    /// 从 ClipboardItem 创建
    convenience init(from item: ClipboardItem) {
        self.init(
            id: item.id,
            timestamp: item.timestamp,
            type: item.type.rawValue,
            content: item.content,
            isPinned: item.isPinned,
            appName: item.appName,
            searchKeywords: item.searchKeywords
        )
    }
    
    /// 转换为 ClipboardItem
    func toClipboardItem() -> ClipboardItem {
        return ClipboardItem(
            type: ClipboardItemType(rawValue: type) ?? .text,
            content: content,
            appName: appName,
            isPinned: isPinned
        )
    }
    
    // MARK: - 查询谓词
    
    /// 按时间范围查询
    static func predicate(from startTime: Date, to endTime: Date) -> Predicate<ClipboardHistoryItem> {
        #Predicate<ClipboardHistoryItem> { item in
            item.timestamp >= startTime && item.timestamp <= endTime
        }
    }
    
    /// 按类型查询
    static func predicate(forType type: String) -> Predicate<ClipboardHistoryItem> {
        #Predicate<ClipboardHistoryItem> { item in
            item.type == type
        }
    }
    
    /// 搜索谓词（搜索关键词已小写存储，传入的 keyword 也需小写）
    static func searchPredicate(for keyword: String) -> Predicate<ClipboardHistoryItem> {
        let lowerKeyword = keyword.lowercased()
        return #Predicate<ClipboardHistoryItem> { item in
            item.searchKeywords.contains(lowerKeyword)
        }
    }
    
    /// 固定项谓词
    static func pinnedPredicate() -> Predicate<ClipboardHistoryItem> {
        #Predicate<ClipboardHistoryItem> { item in
            item.isPinned == true
        }
    }
}
