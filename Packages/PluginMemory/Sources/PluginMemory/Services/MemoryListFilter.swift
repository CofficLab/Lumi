import Foundation

/// 记忆列表的过滤规则。
///
/// 抽成纯函数有两个原因：
/// - 语义可测（`MemorySettingsView` 里的过滤曾因内联在 body 中而难以断言）；
/// - 过滤只需算一次。原先 `filteredItems` 是 View 里的纯计算属性，body 每次求值
///   会读它 3~4 次，每次都全量过滤一遍列表（见 issue #1304）。
enum MemoryListFilter {
    /// 按类型与查询词过滤记忆列表。
    ///
    /// - Parameters:
    ///   - items: 候选记忆条目。
    ///   - type: 类型过滤，`nil` 表示不过滤。
    ///   - query: 查询词，空字符串表示不过滤。
    /// - Returns: 命中的条目，顺序与 `items` 一致。
    static func filter(
        _ items: [MemoryItem],
        type: MemoryType?,
        query: String
    ) -> [MemoryItem] {
        guard type != nil || !query.isEmpty else { return items }

        return items.filter { item in
            let matchesType = type == nil || item.type == type
            let matchesSearch = query.isEmpty
                || item.name.localizedCaseInsensitiveContains(query)
                || item.description.localizedCaseInsensitiveContains(query)
                || item.id.localizedCaseInsensitiveContains(query)
            return matchesType && matchesSearch
        }
    }
}
