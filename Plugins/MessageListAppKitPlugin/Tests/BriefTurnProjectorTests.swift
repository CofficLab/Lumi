import Foundation
import Testing
import LumiKernel
@testable import MessageListAppKitPlugin

struct BriefTurnProjectorTests {
    private func fixture() throws -> FixtureLoader.BriefTurnsFixture {
        try FixtureLoader.briefTurns()
    }

    // MARK: - Stable identity & deterministic ordering

    @Test("结论行按 turn 的 startedAt 升序排列")
    func conclusionOrdering() throws {
        let f = try fixture()
        let records = f.turns.map { FixtureLoader.turnRecord(from: $0, conversationID: f.conversationID) }
        let rows = BriefTurnProjector().project(.init(
            records: records,
            messages: f.messages,
            statusMessage: nil
        ))

        let turnIDs = rows.compactMap(\.sourceTurnID)
        #expect(turnIDs == [
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        ])
    }

    @Test("结论行使用 turn 前缀的稳定 ID")
    func stableRowIDs() throws {
        let f = try fixture()
        let records = f.turns.map { FixtureLoader.turnRecord(from: $0, conversationID: f.conversationID) }
        let rows = BriefTurnProjector().project(.init(
            records: records,
            messages: f.messages,
            statusMessage: nil
        ))

        #expect(rows.allSatisfy { $0.id.hasPrefix("turn-") })
        #expect(rows.map(\.id).count == Set(rows.map(\.id)).count)
    }

    // MARK: - Per-state conclusion selection

    @Test("completed turn 输出最后一条非工具助手结论")
    func completedTurnPicksFinalAssistant() throws {
        let f = try fixture()
        let records = f.turns.map { FixtureLoader.turnRecord(from: $0, conversationID: f.conversationID) }
        let rows = BriefTurnProjector().project(.init(
            records: records,
            messages: f.messages,
            statusMessage: nil
        ))

        let completed = rows.first(where: { $0.sourceTurnID == UUID(uuidString: "11111111-1111-1111-1111-111111111111") })
        #expect(completed != nil)
        #expect(completed?.kind == .conclusion)
        #expect(completed?.message.id == UUID(uuidString: "A0000000-0000-0000-0000-000000000005"))
        #expect(completed?.content.contains("quickSort") == true)
    }

    @Test("failed turn 输出错误结论（错误胜出）")
    func failedTurnPicksError() throws {
        let f = try fixture()
        let records = f.turns.map { FixtureLoader.turnRecord(from: $0, conversationID: f.conversationID) }
        let rows = BriefTurnProjector().project(.init(
            records: records,
            messages: f.messages,
            statusMessage: nil
        ))

        let failed = rows.first(where: { $0.sourceTurnID == UUID(uuidString: "22222222-2222-2222-2222-222222222222") })
        #expect(failed?.kind == .conclusion)
        #expect(failed?.message.role == .error)
        #expect(failed?.message.id == UUID(uuidString: "A0000000-0000-0000-0000-000000000008"))
    }

    @Test("suspended turn 输出最后的助手消息")
    func suspendedTurnPicksLatestAssistant() throws {
        let f = try fixture()
        let records = f.turns.map { FixtureLoader.turnRecord(from: $0, conversationID: f.conversationID) }
        let rows = BriefTurnProjector().project(.init(
            records: records,
            messages: f.messages,
            statusMessage: nil
        ))

        let suspended = rows.first(where: { $0.sourceTurnID == UUID(uuidString: "33333333-3333-3333-3333-333333333333") })
        #expect(suspended?.message.id == UUID(uuidString: "A0000000-0000-0000-0000-000000000010"))
        #expect(suspended?.content.contains("~/bin") == true)
    }

    @Test("cancelled turn 输出助手结论或错误")
    func cancelledTurnPicksConclusion() throws {
        let f = try fixture()
        let records = f.turns.map { FixtureLoader.turnRecord(from: $0, conversationID: f.conversationID) }
        let rows = BriefTurnProjector().project(.init(
            records: records,
            messages: f.messages,
            statusMessage: nil
        ))

        let cancelled = rows.first(where: { $0.sourceTurnID == UUID(uuidString: "66666666-6666-6666-6666-666666666666") })
        #expect(cancelled?.message.id == UUID(uuidString: "A0000000-0000-0000-0000-000000000014"))
    }

    @Test("idle/running turn 不产生任何行")
    func runningAndIdleTurnsEmitNothing() throws {
        let f = try fixture()
        let records = f.turns.map { FixtureLoader.turnRecord(from: $0, conversationID: f.conversationID) }
        let rows = BriefTurnProjector().project(.init(
            records: records,
            messages: f.messages,
            statusMessage: nil
        ))

        let running = UUID(uuidString: "44444444-4444-4444-4444-444444444444")
        let idle = UUID(uuidString: "55555555-5555-5555-5555-555555555555")
        #expect(rows.contains { $0.sourceTurnID == running } == false)
        #expect(rows.contains { $0.sourceTurnID == idle } == false)
    }

    // MARK: - Status row & legacy projection

    @Test("至多一条 status 行附加在结论之后")
    func statusRowAppendedAtEnd() throws {
        let f = try fixture()
        let records = f.turns.map { FixtureLoader.turnRecord(from: $0, conversationID: f.conversationID) }
        let status = f.messages.last(where: { $0.role == .status })
        let rows = BriefTurnProjector().project(.init(
            records: records,
            messages: f.messages,
            statusMessage: status
        ))

        #expect(rows.count == 5) // 4 conclusions + 1 status
        let last = rows.last
        #expect(last?.kind == .status)
        #expect(last?.message.id == UUID(uuidString: "A0000000-0000-0000-0000-000000000015"))
    }

    @Test("无 turn 记录时走遗留结论（错误 + 助手结论）")
    func legacyProjection() throws {
        let f = try fixture()
        // 遗留会话的消息没有 turnID（status 行由调用方单独传入，不进遗留结论）。
        let legacyMessages = f.messages.filter { $0.turnID == nil && $0.role != .status }
        let rows = BriefTurnProjector().project(.init(
            records: [],
            messages: legacyMessages,
            statusMessage: nil
        ))

        // 遗留错误 + 遗留助手结论（A...016 / A...017）。
        #expect(rows.count == 2)
        #expect(rows.first?.message.role == .error)
        #expect(rows.last?.message.role == .assistant)
        #expect(rows.last?.message.id == UUID(uuidString: "A0000000-0000-0000-0000-000000000017"))
    }

    @Test("遗留结论 + status 行合并为最终展示")
    func legacyWithStatus() throws {
        let f = try fixture()
        let legacyMessages = f.messages.filter { $0.turnID == nil && $0.role != .status }
        let status = f.messages.last(where: { $0.role == .status })
        let rows = BriefTurnProjector().project(.init(
            records: [],
            messages: legacyMessages,
            statusMessage: status
        ))

        #expect(rows.count == 3)
        #expect(rows.last?.kind == .status)
    }
}
