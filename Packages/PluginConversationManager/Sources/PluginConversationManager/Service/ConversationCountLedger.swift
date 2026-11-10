import Foundation

/// 对话条数统计账本。
///
/// ## 存在的原因
///
/// 「每天新建了多少对话」原本是每次从会话表实时 COUNT 出来的。这意味着一旦
/// 用户清理了 N 天前的对话，那几天的计数就永久归零——历史曲线塌陷，
/// 「近 30 天总数」和「单日峰值」也跟着变小。
///
/// 账本把这些计数**独立存下来**，语义是「只增不减的创建计数」：
/// 会话被删除时账本不动，因此统计不受清理操作影响。
///
/// ## 为什么桶键是日期字符串而不是时间戳
///
/// 「自然日零点」用 `TimeInterval` 表示是脆弱的：写入侧用 `startOfDay(for:)`，
/// 查询侧用 `date(byAdding: .day,)`，两条路径在**跨夏令时的日子**会相差一小时；
/// 跨本地午夜时基准日也会漂移。两种情况下桶键都对不上，计数会莫名变成 0。
///
/// 改用 `yyyy-MM-dd` 字符串后，键与「哪一天」一一对应，与时区、夏令时、
/// 计算路径都无关。
///
/// ## 生命周期
///
/// 1. **首次建立**：从现有会话表回填一次，把历史补齐（`mergeSeeded`）；
/// 2. **此后**：每次新建会话累加对应桶（`apply`）；
/// 3. **删除**：不动账本。
///
/// ## 为什么用 JSON 文件而不是 SwiftData 实体
///
/// 会话表用的是 SwiftData。往已有库的 schema 里加一个新实体，等于让 Core Data
/// 在用户数据上做一次迁移；而本插件的建库失败路径是「隔离旧库并重建」——
/// 一旦迁移不兼容，用户会丢掉全部会话。账本只是统计副产物，不值得冒这个险。
/// 独立文件没有迁移风险，也便于人工检查。
final class ConversationCountLedger: @unchecked Sendable {

    // MARK: - 常量

    /// 账本保留天数。
    ///
    /// 图表只展示最近 30 天；保留两年足够回答「上个月有多少对话」，
    /// 同时避免文件随时间无限增长。
    static let retentionDays = 730

    /// 账本文件格式版本。版本不匹配时整个文件作废（重新回填）。
    static let fileVersion = 2

    /// 账本文件名。
    static let fileName = "conversation-count-ledger-v2.json"

    // MARK: - 类型

    /// 本地自然日键（`yyyy-MM-dd`）。
    ///
    /// - Parameter date: 任意时刻，取其所在自然日。
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    /// 桶键：自然日 + 项目 + 是否子会话。
    struct BucketKey: Hashable, Sendable {
        /// 自然日键（`yyyy-MM-dd`）。
        let day: String
        /// 所属项目路径；`nil` 表示不属于任何项目。
        let projectPath: String?
        /// 是否为子 Agent 会话。
        let isChildConversation: Bool
    }

    /// 一批计数增量。
    struct Increment: Sendable {
        /// 自然日键（`yyyy-MM-dd`）。
        let day: String
        /// 所属项目路径；`nil` 表示不属于任何项目。
        let projectPath: String?
        /// 是否为子 Agent 会话。
        let isChildConversation: Bool
        /// 增量条数。
        let count: Int
    }

    /// 落盘条目。
    private struct Entry: Codable {
        let day: String
        let projectPath: String?
        let isChildConversation: Bool
        let count: Int
    }

    /// 账本文件内容。
    private struct Payload: Codable {
        let version: Int
        let seeded: Bool
        let entries: [Entry]
    }

    // MARK: - 属性

    private let fileURL: URL?
    /// 各桶的累计计数。
    private var counts: [BucketKey: Int] = [:]
    /// 是否已与现有会话表对齐过。
    private(set) var isSeeded = false
    /// 是否已与现有会话表对齐过（供存储层判断能否跳过回填）。
    var isSeededFromTable: Bool { isSeeded }
    private var isLoaded = false

    // MARK: - 初始化

    init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    // MARK: - 读取

    /// 从磁盘加载账本（幂等）。
    ///
    /// 必须在判断「是否已回填」之前调用：否则每次启动都会以为账本是空的，
    /// 从而把整张会话表重新扫一遍。
    func load() {
        loadIfNeeded()
    }

    /// 各自然日的对话数（键为自然日键 `yyyy-MM-dd`）。
    ///
    /// - Parameters:
    ///   - projectPath: 只统计该项目的对话；`nil` 表示全部项目合计。
    ///   - includingChildConversations: 是否把子 Agent 会话计入。
    func dailyCounts(
        projectPath: String?,
        includingChildConversations: Bool
    ) -> [String: Int] {
        loadIfNeeded()
        var result: [String: Int] = [:]
        for (key, count) in counts {
            if let projectPath, key.projectPath != projectPath { continue }
            if !includingChildConversations, key.isChildConversation { continue }
            result[key.day, default: 0] += count
        }
        return result
    }

    // MARK: - 写入

    /// 应用一批增量并落盘。
    func apply(_ increments: [Increment]) {
        loadIfNeeded()
        guard !increments.isEmpty else { return }
        for increment in increments {
            let key = BucketKey(
                day: increment.day,
                projectPath: increment.projectPath,
                isChildConversation: increment.isChildConversation
            )
            counts[key, default: 0] += increment.count
        }
        prune()
        save()
    }

    /// 用会话表的现状回填账本（只在账本首次建立时调用一次）。
    ///
    /// 取「账本值」与「表值」的较大者：账本可能已经记着表里看不到的历史
    /// （那些会话已被删除），这时不能被表值拉低。
    func mergeSeeded(tableCounts: [BucketKey: Int]) {
        loadIfNeeded()
        for (key, count) in tableCounts {
            counts[key] = max(counts[key] ?? 0, count)
        }
        isSeeded = true
        prune()
        save()
    }

    // MARK: - 私有

    /// 首次访问时加载账本文件。
    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.version == Self.fileVersion else { return }
        for entry in payload.entries {
            let key = BucketKey(
                day: entry.day,
                projectPath: entry.projectPath,
                isChildConversation: entry.isChildConversation
            )
            counts[key] = entry.count
        }
        isSeeded = payload.seeded
    }

    /// 落盘账本。
    private func save() {
        guard let fileURL else { return }
        let entries = counts
            .map { key, count in
                Entry(
                    day: key.day,
                    projectPath: key.projectPath,
                    isChildConversation: key.isChildConversation,
                    count: count
                )
            }
            .sorted { lhs, rhs in
                if lhs.day != rhs.day { return lhs.day < rhs.day }
                if lhs.projectPath != rhs.projectPath {
                    return (lhs.projectPath ?? "") < (rhs.projectPath ?? "")
                }
                return !lhs.isChildConversation && rhs.isChildConversation
            }
        let payload = Payload(version: Self.fileVersion, seeded: isSeeded, entries: entries)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 丢弃保留窗口之外的桶，避免账本文件无限增长。
    ///
    /// 用日期键的字典序比较即可：`yyyy-MM-dd` 是定长且字典序与时间序一致。
    private func prune() {
        let cutoffDate = Calendar.current.startOfDay(for: Date())
            .addingTimeInterval(-Double(Self.retentionDays) * 86_400)
        let cutoffKey = Self.dayKey(for: cutoffDate)
        counts = counts.filter { $0.key.day >= cutoffKey }
    }
}
