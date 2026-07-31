import Foundation
@testable import LumiKernel

/// 测试用 `LegacyDataProviding` 实现。
///
/// 通过可配置的 stub 字段模拟 v4 旧数据读取,验证协议契约与内核注册链路。
/// 真实实现(LegacyDataService,含复制副本 + SwiftData 打开)在插件层,不在此测试范围。
@MainActor
final class MockLegacyDataProviding: LegacyDataProviding {
    var stubRootDirectory: URL? = URL(fileURLWithPath: "/db_production_v4")

    /// 显式覆写 hasLegacyData();nil 时跟随 stubRootDirectory 是否存在(模拟真实实现)。
    var overrideHasLegacyData: Bool? = nil
    var stubConversations: [LumiConversationSummary] = []
    var stubMessagesByConversation: [UUID: [LumiChatMessage]] = [:]
    var fetchConversationsThrows: Bool = false

    private(set) var releaseCallCount: Int = 0

    var legacyDataRootDirectory: URL? { stubRootDirectory }

    /// 真实实现里:目录不存在即无旧数据。Mock 模拟此联动 —— 除非显式覆写。
    func hasLegacyData() -> Bool {
        if let overrideHasLegacyData { return overrideHasLegacyData }
        return stubRootDirectory != nil
    }

    func fetchLegacyConversations() throws -> [LumiConversationSummary] {
        if fetchConversationsThrows {
            throw LegacyDataError.fetchFailed(
                entity: "Conversation",
                underlying: NSError(domain: "test", code: 1)
            )
        }
        return stubConversations
    }

    func fetchLegacyMessages(for conversationID: UUID) throws -> [LumiChatMessage] {
        if fetchConversationsThrows {
            throw LegacyDataError.fetchFailed(
                entity: "ChatMessageEntity",
                underlying: NSError(domain: "test", code: 2)
            )
        }
        return stubMessagesByConversation[conversationID] ?? []
    }

    func releaseLegacySnapshot() {
        releaseCallCount += 1
    }
}
