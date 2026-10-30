import Foundation

/// 每日对话计数序列中的单个数据点。
///
/// 一天对应一个点；没有对话的那天计数为 0（不是缺失），这样折线图不会断点。
public struct ConversationDailyCountPoint: Equatable, Identifiable, Sendable {
    /// 该计数对应的自然日零点。
    public let day: Date
    /// 当天的对话数量。
    public let count: Int

    public var id: Date { day }

    public init(day: Date, count: Int) {
        self.day = day
        self.count = count
    }
}

/// 参与每日聚合的最小会话信息。
///
/// 每日统计只需要「什么时候创建、属于哪个项目、是不是子 Agent 会话」，
/// 因此不必把标题、模型等字段搬进统计链路。
public struct ConversationCreationRecord: Sendable {
    /// 会话创建时间。
    public let createdAt: Date
    /// 所属项目路径；`nil` 表示不属于任何项目。
    public let projectPath: String?
    /// 是否由子 Agent 创建。
    public let isChildConversation: Bool

    public init(createdAt: Date, projectPath: String?, isChildConversation: Bool) {
        self.createdAt = createdAt
        self.projectPath = projectPath
        self.isChildConversation = isChildConversation
    }
}

/// 每日对话计数序列。
///
/// 按**创建日**聚合（与「清理 N 天前的对话」的口径一致：一条对话在图上
/// 落在哪一天，就属于哪一天）。
public struct ConversationDailyCountSeries: Equatable, Sendable {
    public let points: [ConversationDailyCountPoint]

    public init(points: [ConversationDailyCountPoint]) {
        self.points = points
    }

    /// 序列内的单日峰值。
    public var peakCount: Int {
        points.map(\.count).max() ?? 0
    }

    /// 序列覆盖区间内的对话总数。
    public var totalCount: Int {
        points.reduce(0) { $0 + $1.count }
    }

    /// 按自然日聚合会话创建时间，得到从 `endingAt` 往前数 `days` 天的每日计数。
    ///
    /// - Parameters:
    ///   - records: 待聚合的会话创建记录。
    ///   - days: 序列长度（向前回溯的天数）。
    ///   - projectPath: 只统计该项目的对话；`nil` 表示全部项目。
    ///   - includingChildConversations: 是否把子 Agent 会话计入。
    ///   - calendar: 用于切分自然日的日历。
    ///   - endingAt: 序列的最后一天（按其所在自然日取零点）。
    public static func build(
        from records: [ConversationCreationRecord],
        days: Int,
        projectPath: String? = nil,
        includingChildConversations: Bool = false,
        calendar: Calendar = .current,
        endingAt: Date = Date()
    ) -> ConversationDailyCountSeries {
        guard days > 0 else { return ConversationDailyCountSeries(points: []) }

        let today = calendar.startOfDay(for: endingAt)
        guard let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return ConversationDailyCountSeries(points: [])
        }

        var buckets: [Date: Int] = [:]
        for record in records {
            if !includingChildConversations, record.isChildConversation { continue }
            if let projectPath, record.projectPath != projectPath { continue }
            let day = calendar.startOfDay(for: record.createdAt)
            guard day >= firstDay, day <= today else { continue }
            buckets[day, default: 0] += 1
        }

        let points = (0..<days).compactMap { offset -> ConversationDailyCountPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            return ConversationDailyCountPoint(day: day, count: buckets[day, default: 0])
        }
        return ConversationDailyCountSeries(points: points)
    }
}
