import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 日统计聚合（活动热力图口径）不得物化整张消息表，也不得占用存储层全局锁。
///
/// ## 背景
///
/// `MessageStore.dailyMessageCounts/dailyTokenCounts/dailyAggregate` 原先用
/// SwiftData 把「since 之后的全部行」取回内存，再在 Swift 侧按天聚合。
/// 生产库 5.6 万行 / 400MB 时实测单次耗时 **4.6 秒**，且全程持有 `MessageStore`
/// 的全局写锁——热力图一打开，所有消息写入被阻塞近 5 秒。
///
/// 聚合真正需要的只有「创建时间 + token 数」，正文列完全用不到。
@Suite("MessageStore 日统计聚合")
struct MessageStoreDailyAggregateTests {
    private func makeStore() throws -> (store: MessageStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageStoreDaily-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    /// 取出存储层的写锁（`MessageStore` 用它串行化全部 SwiftData 访问）。
    ///
    /// 按类型而非按名字查找：实现改了锁的属性名也不至于让用例误报。
    private func storeWriteLock(in store: MessageStore) -> NSLock? {
        Mirror(reflecting: store).children.compactMap { $0.value as? NSLock }.first
    }

    /// 聚合是纯读路径：它不得占用存储层的写锁。
    ///
    /// - Important: 断言方式选「测试线程占住锁 → 聚合仍能完成」，而不是断言耗时。
    ///   前者是确定性的（阻塞 / 不阻塞二选一），后者随机器负载抖动。
    ///   这条不变式正是用户可感知的症状：热力图统计不得把消息写入堵住。
    @Test("日统计聚合不得占用存储层全局锁")
    func dailyAggregationDoesNotRequireStoreLock() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        try store.insertMessage(Message(
            conversationID: conversationID, role: .user, content: "hi",
            createdAt: Date(), inputTokenCount: 3
        ))

        guard let lock = storeWriteLock(in: store) else {
            // 存储层已不再持有 NSLock → 不变式天然成立。
            return
        }

        lock.lock()
        defer { lock.unlock() }

        let finished = DispatchSemaphore(value: 0)
        let box = ResultBox()
        DispatchQueue.global().async {
            box.set(store.dailyMessageCounts(since: .distantPast))
            finished.signal()
        }

        #expect(
            finished.wait(timeout: .now() + 10) == .success,
            "日统计聚合被存储层全局锁阻塞——它必须走不占用写锁的只读路径"
        )
        #expect(box.value.isEmpty == false, "聚合结果不应为空")
    }

    /// 聚合口径必须与「逐条读出再在 Swift 侧聚合」完全一致。
    ///
    /// 覆盖本地日边界（23:59:59 与次日 00:00:00 必须分属两天）与
    /// 0-token 消息（token 口径下不计入、条数口径下计入一条）。
    ///
    /// - Important: 消息**乱序**插入且日期间有缺口。聚合按时间戳逐行归桶，
    ///   必须处理「先见到后一天、再见到前一天」这类顺序——否则同一条消息
    ///   会被归错桶。
    @Test("日统计聚合口径必须与逐条读取一致")
    func dailyAggregationMatchesRowByRowReference() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 40 天，每天 3 条；刻意跳过一半的日子形成缺口，并打乱插入顺序。
        var samples: [(Date, Int?, Int?)] = []
        for dayOffset in 0..<40 {
            guard dayOffset.isMultiple(of: 2) else { continue }
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let boundary = day.addingTimeInterval(86_399)  // 当天 23:59:59
            samples.append((day, 10, nil))
            samples.append((day.addingTimeInterval(3600), nil, 7))
            samples.append((boundary, nil, nil))  // 0 token：条数计 1，token 不计
        }
        // 倒序插入：后一天先落库。
        for (index, sample) in samples.enumerated().reversed() {
            try store.insertMessage(Message(
                conversationID: conversationID,
                role: .user,
                content: "m\(index)",
                createdAt: sample.0,
                inputTokenCount: sample.1,
                outputTokenCount: sample.2
            ))
        }

        // 参考口径：逐条读出后在 Swift 侧按 Calendar.current.startOfDay 聚合。
        let messages = store.fetchMessages(conversationId: conversationID)
        #expect(messages.count == samples.count)
        var expectedCounts: [Date: Int] = [:]
        var expectedTokens: [Date: Int] = [:]
        for message in messages {
            let day = calendar.startOfDay(for: message.createdAt)
            expectedCounts[day, default: 0] += 1
            let tokens = (message.inputTokenCount ?? 0) + (message.outputTokenCount ?? 0)
            guard tokens > 0 else { continue }
            expectedTokens[day, default: 0] += tokens
        }
        #expect(expectedCounts.count == 20)
        #expect(expectedTokens.count == 20)

        #expect(store.dailyMessageCounts(since: .distantPast) == expectedCounts)
        #expect(store.dailyTokenCounts(since: .distantPast) == expectedTokens)
    }

    /// 磁盘侧必须按 id 排除调用方给出的消息——调用方会把它们按 pending 口径补计。
    ///
    /// - Important: 被排除的消息即使**已经落盘**也必须从磁盘侧剔除；
    ///   否则调用方再补一次就变成重复计数。
    @Test("日统计聚合必须按 id 排除调用方指定的消息")
    func dailyAggregateExcludesGivenIdentifiers() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let day = Calendar.current.startOfDay(for: Date())
        let kept = Message(
            conversationID: conversationID, role: .user, content: "keep",
            createdAt: day, inputTokenCount: 4
        )
        let excluded = Message(
            conversationID: conversationID, role: .assistant, content: "drop",
            createdAt: day, inputTokenCount: 6
        )
        try store.insertMessage(kept)
        try store.insertMessage(excluded)

        let excludedIDs: Set<String> = [excluded.id.uuidString]

        let counts = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: excludedIDs,
            countTokens: false
        )
        #expect(counts[day] == 1)

        let tokens = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: excludedIDs,
            countTokens: true
        )
        #expect(tokens[day] == 4)

        // 不排除时两条都在。
        let all = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: [],
            countTokens: false
        )
        #expect(all[day] == 2)
    }

    /// 大数据量下的日统计聚合必须保持有界——不得退化成「逐行物化整表」。
    ///
    /// - Important: 聚合只需要「创建时间 + token 数」。SwiftData 的表把正文
    ///   `ZCONTENT` 排在 `ZCREATEDAT` **之后**，读正文列必须顺着记录跨过
    ///   overflow 页——代价与正文体积成正比。旧实现把整行（含正文）取回内存，
    ///   于是「一条 16MB 正文」就能把一次聚合拖到几百毫秒。
    ///
    ///   这里用「5000 行 + 一条 16MB 正文」把正文读取的代价放大，
    ///   使「读了正文 / 没读正文」的差别足以被时间断言稳定区分。
    @Test("大数据量下日统计聚合必须保持有界")
    func dailyAggregationStaysBoundedAtScale() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<5000 {
            try store.insertMessage(Message(
                conversationID: conversationID,
                role: index.isMultiple(of: 2) ? .user : .assistant,
                content: "消息 \(index) " + String(repeating: "内容", count: 20),
                createdAt: base.addingTimeInterval(Double(index)),
                inputTokenCount: index.isMultiple(of: 3) ? 5 : nil
            ))
        }
        // 一条正文巨大的消息：读它必须跨 overflow 页。
        try store.insertMessage(Message(
            conversationID: conversationID, role: .assistant,
            content: String(repeating: "巨", count: 4 * 1024 * 1024),  // 16MB
            createdAt: base.addingTimeInterval(5000),
            inputTokenCount: 1
        ))

        let start = Date()
        let counts = store.dailyMessageCounts(since: .distantPast)
        let elapsed = Date().timeIntervalSince(start)
        print("DAILY scale counts=\(counts.count) elapsed=\(elapsed)s")

        #expect(counts.count == 1)
        #expect(counts.values.reduce(0, +) == 5001)
        #expect(elapsed < 0.1, "日统计聚合耗时 \(elapsed)s，疑似逐行物化整表")
    }
}

/// 跨线程回传聚合结果的容器（Swift 6 严格并发下需要显式同步）。
private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Date: Int] = [:]

    var value: [Date: Int] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ newValue: [Date: Int]) {
        lock.lock()
        defer { lock.unlock() }
        storage = newValue
    }
}
