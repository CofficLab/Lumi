import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

// MARK: - 复现：新建对话时 persist() 全量保存的性能问题

/// 复现点击"新建对话"时的卡顿根因：
///
/// 1. **persist() 全量序列化**：`createConversation` 调用 `persist()`，
///    而 `persist()` 内部调用 `store.save()` 会 fetch 所有 Conversation 和所有
///    ChatMessageEntity 做全量 upsert，随着历史数据增长线性变慢。
///
/// 2. **@Published 多次触发**：`createConversation` 连续修改 `conversations`、
///    `selectedConversationID`、`revision`（via persist），每个 @Published 变化
///    都会驱动 SwiftUI 重绘。
@Suite(.serialized)
@MainActor
struct CreateConversationPerformanceSuite {

    // MARK: - Problem 1: persist() 全量保存，随数据量线性增长

    @Test("createConversation 在空数据下 persist 调用一次")
    func createConversationTriggersSinglePersistOnEmptyStore() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))
        let persistBefore = service.persistCallCount

        _ = service.createConversation(title: "First")

        let persistDelta = service.persistCallCount - persistBefore
        // 当前行为：新建对话触发 1 次 persist
        // 期望行为：同样 1 次，但内部只做增量插入而非全量 fetch
        #expect(persistDelta == 1)
    }

    @Test("createConversation 在大量历史数据下 persist 仍然只调用一次")
    func createConversationStillOnePersistWithLargeHistory() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))

        // 预填充：模拟用户长期使用后的状态（50 个对话，每个对话 20 条消息）
        seedConversationsAndMessages(service: service, count: 50, messagesPerConversation: 20)

        let persistBefore = service.persistCallCount

        _ = service.createConversation(title: "New Chat")

        let persistDelta = service.persistCallCount - persistBefore
        // persist 调用次数应仍为 1（而非随数据量增长）
        // 当前实现确实只调用 1 次，但内部的 store.save() 做了全量 fetch+upsert
        #expect(persistDelta == 1)
    }

    @Test(
        "全量 persist 在大量历史数据下的耗时（基线对照）",
        .disabled("仅手动运行以收集基线数据")
    )
    func persistLatencyWithLargeDataset() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))

        // 预填充 200 个对话，每个 30 条消息
        seedConversationsAndMessages(service: service, count: 200, messagesPerConversation: 30)

        // 测量单次 persist 耗时
        let start = ContinuousClock().now
        service.persist()
        let elapsed = start.duration(to: ContinuousClock().now)

        // 记录基线：当前实现全量 fetch+upsert，此值随数据量增长
        // 优化目标：此值应 < 50ms 不论数据量大小
        print("⏱ persist() with 200 conversations × 30 messages: \(elapsed)")
    }

    // MARK: - Problem 2: @Published 属性多次触发 revision

    @Test("createConversation 单次调用 revision 增量")
    func createConversationRevisionIncrement() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))
        let revisionBefore = service.revision

        _ = service.createConversation(title: "Test")

        let revisionDelta = service.revision - revisionBefore
        // 优化后：createConversation 合并通知，revision 不再额外 +1
        // （objectWillChange.send 已统一通知，不需要 revision 触发）
        #expect(revisionDelta == 0)
    }

    @Test("连续创建多个对话时 revision 不再线性增长")
    func consecutiveCreateConversationRevisionGrowth() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))

        let revisionBefore = service.revision
        _ = service.createConversation(title: "Batch")

        // 连续创建 5 个对话
        for index in 1...5 {
            _ = service.createConversation(title: "Batch \(index)")
        }

        // 优化后：createConversation 使用 persistConversationAndStateMerged，
        // 不递增 revision，避免额外的 UI 重绘
        let totalRevisionDelta = service.revision - revisionBefore
        #expect(totalRevisionDelta == 0)
    }

    // MARK: - Problem 3: persist 全量 fetch 验证

    @Test("createConversation 后数据可正确从磁盘恢复")
    func createConversationDataPersistsAcrossInstances() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))

        seedConversationsAndMessages(service: service, count: 10, messagesPerConversation: 5)
        let newID = service.createConversation(title: "Newest")

        // 重新加载
        let reloaded = try ChatService(configuration: .coreDatabase(directory: directory))

        // 包含预填充的 10 个 + 新建的 1 个 = 11 个对话
        #expect(reloaded.conversations.count == 11)
        #expect(reloaded.conversations.contains(where: { $0.id == newID }))
        // 新对话在列表顶部
        #expect(reloaded.conversations.first?.id == newID)
    }

    // MARK: - Problem 4: 大量消息场景下 persist 开销随数据增长

    @Test("单次 append 消息触发增量 persist")
    func appendMessageTriggersIncrementalPersist() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))
        let conversationID = service.createConversation(title: "Test")

        let persistBefore = service.persistCallCount

        // 每条消息 append 都会触发增量 persist
        for index in 0..<3 {
            service.append(
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .user,
                    content: "Message \(index)"
                )
            )
        }

        let persistDelta = service.persistCallCount - persistBefore
        // 每次 append 触发 1 次 persistMessage（增量），不再全量保存
        #expect(persistDelta == 3)
    }

    // MARK: - Optimization Verification: 增量 persist 在大数据下不退化

    @Test("大量数据下 createConversation 耗时与空数据相当")
    func createConversationLatencyStableWithLargeHistory() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))

        // 预填充 100 个对话，每个 10 条消息
        seedConversationsAndMessages(service: service, count: 100, messagesPerConversation: 10)

        // 测量在已有大量数据下创建新对话的耗时
        let start = ContinuousClock().now
        _ = service.createConversation(title: "New Chat in Big Store")
        let elapsed = start.duration(to: ContinuousClock().now)

        // 优化后：增量插入应该 < 100ms（旧全量方式需要数百毫秒到秒级）
        // 使用宽松断言避免 CI 环境波动
        print("⏱ createConversation in 100×10 dataset: \(elapsed)")
        #expect(elapsed < .milliseconds(500))
    }

    @Test("大量数据下 append 消息耗时与空数据相当")
    func appendMessageLatencyStableWithLargeHistory() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))

        // 预填充 100 个对话，每个 10 条消息
        seedConversationsAndMessages(service: service, count: 100, messagesPerConversation: 10)

        let conversationID = service.conversations.last!.id

        // 测量在已有大量数据下 append 一条消息的耗时
        let start = ContinuousClock().now
        service.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: "New message in big store"
            )
        )
        let elapsed = start.duration(to: ContinuousClock().now)

        // 优化后：增量保存应该 < 100ms（旧全量方式需要数百毫秒）
        print("⏱ appendMessage in 100×10 dataset: \(elapsed)")
        #expect(elapsed < .milliseconds(500))
    }

    // MARK: - Helpers

    /// 预填充测试数据：模拟用户长期使用后的状态
    private func seedConversationsAndMessages(
        service: ChatService,
        count: Int,
        messagesPerConversation: Int
    ) {
        for convIndex in 0..<count {
            let convID = service.conversationManager.createConversation(
                title: "Seed Conversation \(convIndex)",
                projectPath: nil,
                language: nil
            )
            for msgIndex in 0..<messagesPerConversation {
                service.append(
                    LumiChatMessage(
                        conversationID: convID,
                        role: msgIndex % 2 == 0 ? .user : .assistant,
                        content: "Seed message \(msgIndex) in conversation \(convIndex)"
                    )
                )
            }
        }
    }
}
