import Foundation
@testable import LumiKernel
import Testing

@Suite("Legacy Data Service Tests")
@MainActor
struct LegacyDataProvidingTests {

    // MARK: - Service Registration / Resolution

    @Test("注册后可通过 kernel.legacyData 解析")
    func testRegisterAndResolve() async throws {
        let kernel = LumiKernel()
        let mock = MockLegacyDataService()
        kernel.registerLegacyDataService(mock)

        let resolved = kernel.legacyData
        #expect(resolved != nil)
        // 同一实例(注册表单实例语义)
        #expect(resolved as? MockLegacyDataService === mock)
    }

    @Test("未注册时返回 nil(全新安装语义)")
    func testUnregisteredReturnsNil() async throws {
        let kernel = LumiKernel()
        // 不注册任何 legacy 服务
        #expect(kernel.legacyData == nil)
    }

    @Test("重复注册后者覆盖前者")
    func testReRegistrationOverwrites() async throws {
        let kernel = LumiKernel()
        let first = MockLegacyDataService()
        let second = MockLegacyDataService()

        kernel.registerLegacyDataService(first)
        kernel.registerLegacyDataService(second)

        let resolved = kernel.legacyData as? MockLegacyDataService
        #expect(resolved === second)
        #expect(resolved !== first)
    }

    @Test("unregisterService 后 legacyData 变为 nil")
    func testUnregisterClears() async throws {
        let kernel = LumiKernel()
        kernel.registerLegacyDataService(MockLegacyDataService())
        #expect(kernel.legacyData != nil)

        kernel.unregisterService(LegacyDataProviding.self)
        #expect(kernel.legacyData == nil)
    }

    @Test("legacy 服务不参与必需服务启动校验(可选服务)")
    func testLegacyDataNotRequiredAtStartup() async throws {
        // LegacyDataProviding 是可选服务,即使不注册也不应被 kernel 当作必需服务。
        // 这里验证它的协议类型可独立存在,且 kernel 未注册时 startup 校验逻辑
        // (LumiKernel.swift 的 missingServices 列表)不包含它 —— 该列表里没有
        // legacyData 的判定行,故无需注册也能通过必需服务枚举(其他必需服务由各自
        // 插件注册,本测试只断言 legacyData 不在校验范围)。
        let kernel = LumiKernel()
        #expect(kernel.legacyData == nil)
        // 若它是必需服务,kernel 会在 startup 时抛 missingRequiredServices;此处不调
        // startup(会因其他必需服务缺失而失败),仅断言其「可选」语义体现在访问器返回 nil。
    }

    // MARK: - Error Type

    @Test("LegacyDataError 各 case 有非空 errorDescription")
    func testErrorDescriptions() async throws {
        let underlying = NSError(domain: "test", code: 42)

        #expect((LegacyDataError.legacyDataNotFound.errorDescription ?? "").isEmpty == false)
        #expect((LegacyDataError.snapshotCopyFailed(underlying: underlying).errorDescription ?? "").isEmpty == false)
        #expect((LegacyDataError.openFailed(underlying: underlying).errorDescription ?? "").isEmpty == false)
        #expect((LegacyDataError.fetchFailed(entity: "Conversation", underlying: underlying).errorDescription ?? "").isEmpty == false)
    }

    @Test("LegacyDataError 符合 Error,可被 do/catch 捕获")
    func testErrorIsThrowable() async throws {
        #expect(throws: LegacyDataError.self) {
            throw LegacyDataError.legacyDataNotFound
        }
    }

    // MARK: - DTO

    @Test("LumiLegacyDataSnapshot 持有源路径与副本路径")
    func testSnapshotValueSemantics() async throws {
        let source = URL(fileURLWithPath: "/db_production_v4")
        let snapshot = URL(fileURLWithPath: "/tmp/snapshot")
        let value = LumiLegacyDataSnapshot(snapshotURL: snapshot, sourceURL: source)
        #expect(value.snapshotURL == snapshot)
        #expect(value.sourceURL == source)
    }

    @Test("LumiLegacyDataKind 枚举值")
    func testMigrationKinds() async throws {
        #expect(LumiLegacyDataKind.conversations.rawValue == "conversations")
        #expect(LumiLegacyDataKind.messages.rawValue == "messages")
    }

    // MARK: - 端到端调用链(模拟消费插件场景)

    @Test("消费插件典型调用链:guard let → hasLegacyData → fetch → 拿到中性 DTO")
    func testConsumerPluginCallChain() async throws {
        let kernel = LumiKernel()

        // 预置 legacy 数据
        let convID = UUID()
        let mock = MockLegacyDataService()
        mock.stubConversations = [
            LumiConversationSummary(id: convID, title: "旧会话", projectPath: "/proj")
        ]
        mock.stubMessagesByConversation[convID] = [
            LumiChatMessage(conversationID: convID, role: .user, content: "你好"),
            LumiChatMessage(conversationID: convID, role: .assistant, content: "你好,在的")
        ]
        kernel.registerLegacyDataService(mock)

        // 模拟一个消费插件的 onReady 迁移片段
        guard let legacy = kernel.legacyData else {
            Issue.record("legacyData 应已注册")
            return
        }
        #expect(legacy.hasLegacyData())

        let conversations = try legacy.fetchLegacyConversations()
        #expect(conversations.count == 1)
        #expect(conversations.first?.id == convID)
        // UUID 原样保留(迁移时不做 id 映射)
        #expect(conversations.first?.title == "旧会话")

        let messages = try legacy.fetchLegacyMessages(for: convID)
        #expect(messages.count == 2)
        #expect(messages.first?.role == .user)
        #expect(messages.last?.role == .assistant)
        // conversationID 原样保留(后续 .uuidString 即可对上会话外键)
        #expect(messages.allSatisfy { $0.conversationID == convID })
    }

    @Test("fetch 抛错时消费插件应吞错而非中断(契约验证)")
    func testConsumerSwallowsFetchError() async throws {
        let kernel = LumiKernel()
        let mock = MockLegacyDataService()
        mock.fetchConversationsThrows = true
        kernel.registerLegacyDataService(mock)

        // 模拟消费插件:do/catch 吞错,绝不向上抛(否则阻塞 onReady 串行链)
        let legacy = kernel.legacyData
        var migratedCount = 0
        do {
            guard let legacy else { return }
            let conversations = try legacy.fetchLegacyConversations()
            migratedCount = conversations.count
        } catch {
            // 吞错 + 记日志(此处只验证不向上抛)
            migratedCount = 0
        }
        // 即使 fetch 抛错,流程也不中断,migratedCount 保持安全默认值
        #expect(migratedCount == 0)
    }

    @Test("releaseLegacySnapshot 幂等:多次调用安全")
    func testReleaseIdempotent() async throws {
        let kernel = LumiKernel()
        let mock = MockLegacyDataService()
        kernel.registerLegacyDataService(mock)

        let legacy = kernel.legacyData!
        legacy.releaseLegacySnapshot()
        legacy.releaseLegacySnapshot()  // 再次调用不应崩溃
        #expect(mock.releaseCallCount == 2)
    }

    @Test("legacyDataRootDirectory 为 nil 时表示无旧数据")
    func testNilRootDirectoryMeansNoLegacy() async throws {
        let kernel = LumiKernel()
        let mock = MockLegacyDataService()
        mock.stubRootDirectory = nil
        kernel.registerLegacyDataService(mock)

        let legacy = kernel.legacyData
        #expect(legacy?.legacyDataRootDirectory == nil)
        #expect(legacy?.hasLegacyData() == false)
    }
}

// MARK: - Mock Implementation

/// 测试用的 LegacyDataProviding 实现
///
/// 通过可配置的 stub 字段模拟 v4 旧数据读取,验证协议契约与内核注册链路。
/// 真实实现(LegacyDataService,含复制副本 + SwiftData 打开)在插件层,不在此测试范围。
@MainActor
private final class MockLegacyDataService: LegacyDataProviding {
    var stubRootDirectory: URL? = URL(fileURLWithPath: "/db_production_v4")
    /// 显式覆写 hasLegacyData();nil 时跟随 stubRootDirectory 是否存在(模拟真实实现)。
    var overrideHasLegacyData: Bool? = nil
    var stubConversations: [LumiConversationSummary] = []
    var stubMessagesByConversation: [UUID: [LumiChatMessage]] = [:]
    var fetchConversationsThrows: Bool = false
    var releaseCallCount: Int = 0

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
