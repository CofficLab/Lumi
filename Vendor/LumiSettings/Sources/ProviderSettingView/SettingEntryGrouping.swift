import Foundation

/// 设置入口的分组归拢。
///
/// macOS 侧用侧边栏平铺入口，不需要分组；iOS 侧用分组列表（Settings.app 风格），
/// 插件通过声明自己的分组，让根页具备可扫读的语义层级。
///
/// 归拢规则：
/// - 入口按 `SettingEntryItem.group` 分组，未声明分组的入口归入末尾的无标题分组；
/// - 显式分组按 `group.order` 排序，兜底分组永远排在最后；
/// - 同组内保持 `entry.order` 的既有排序。
public enum SettingEntryGrouping {
    /// 一个分组。
    public struct Section: Identifiable {
        public let id: String
        public let order: Int
        /// 分组标题；兜底分组没有标题。
        public let title: String?
        public let entries: [SettingEntryItem]

        public init(id: String, order: Int, title: String?, entries: [SettingEntryItem]) {
            self.id = id
            self.order = order
            self.title = title
            self.entries = entries
        }
    }

    /// 按关键词过滤入口（标题模糊匹配，空关键词表示不过滤）。
    public static func filter(_ entries: [SettingEntryItem], keyword: String) -> [SettingEntryItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    /// 把入口归拢成分组。
    public static func sections(from entries: [SettingEntryItem]) -> [Section] {
        var buckets: [String: Bucket] = [:]
        for entry in entries {
            let groupID = entry.group?.id ?? SettingEntryFallbackGroup.id
            var bucket = buckets[groupID] ?? Bucket(
                order: entry.group?.order ?? Int.max,
                title: entry.group?.title
            )
            bucket.entries.append(entry)
            buckets[groupID] = bucket
        }

        return buckets
            .map { bucket in
                Section(
                    id: bucket.key,
                    order: bucket.value.order,
                    title: resolvedTitle(for: bucket.value),
                    entries: bucket.value.entries
                )
            }
            .sorted { lhs, rhs in
                // 兜底分组永远排在最后；其余按 group.order 排序。
                if lhs.id == SettingEntryFallbackGroup.id { return false }
                if rhs.id == SettingEntryFallbackGroup.id { return true }
                if lhs.order == rhs.order { return lhs.id < rhs.id }
                return lhs.order < rhs.order
            }
    }

    /// 分组标题：与组内唯一条目标题相同时不显示标题。
    ///
    /// 插件把入口放进同名分组很常见（例如「外观」分组里只有一个「外观」页），
    /// 这时标题只是把同一行文字重复一遍，白白吃掉一行高度。iOS 根页是
    /// 「页面选择器」，标题应当提供分组之外的信息，而不是复述行标题。
    private static func resolvedTitle(for bucket: Bucket) -> String? {
        guard let title = bucket.title, !title.isEmpty else { return nil }
        if bucket.entries.count == 1, bucket.entries[0].title == title {
            return nil
        }
        return title
    }

    /// 过滤并归拢的组合入口。
    public static func sections(from entries: [SettingEntryItem], keyword: String) -> [Section] {
        sections(from: filter(entries, keyword: keyword))
    }

    // MARK: - Cards

    /// 渲染用卡片：把连续的「无标题分组」合并成同一张卡片。
    ///
    /// iOS 的 inset grouped 列表里，`Section` 就是一张卡片。分组标题被隐藏
    /// （见 `resolvedTitle`）后，相邻的无标题分组若各占一张卡片，就会得到
    /// 「一卡一行」的零碎列表；合并后才是 iOS Settings 里常见的紧凑分组。
    ///
    /// 有标题的分组永远自成一卡（标题就是这张卡片的语义标签）。
    public struct Card: Identifiable {
        public let id: String
        /// 卡片标题；无标题卡片为 nil。
        public let title: String?
        public let entries: [SettingEntryItem]

        public init(id: String, title: String?, entries: [SettingEntryItem]) {
            self.id = id
            self.title = title
            self.entries = entries
        }
    }

    /// 把分组归并成卡片。
    public static func cards(from sections: [Section]) -> [Card] {
        var cards: [Card] = []
        for section in sections {
            if let title = section.title {
                cards.append(Card(id: section.id, title: title, entries: section.entries))
                continue
            }
            // 无标题分组：并入上一张「同样无标题」的卡片，否则自立一张。
            if let last = cards.last, last.title == nil {
                cards[cards.count - 1] = Card(
                    id: last.id,
                    title: nil,
                    entries: last.entries + section.entries
                )
            } else {
                cards.append(Card(id: section.id, title: nil, entries: section.entries))
            }
        }
        return cards
    }

    /// 过滤、归拢并合并成卡片的组合入口。
    public static func cards(from entries: [SettingEntryItem], keyword: String) -> [Card] {
        cards(from: sections(from: filter(entries, keyword: keyword)))
    }

    private struct Bucket {
        let order: Int
        let title: String?
        var entries: [SettingEntryItem] = []
    }
}
