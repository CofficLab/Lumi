import Foundation
import LumiKernel

/// Loads the JSON/Markdown fixtures under `Tests/Fixtures/` into typed models.
///
/// `LumiChatMessage` uses the synthesized Codable shape (dates as
/// `timeIntervalSinceReferenceDate` doubles); `AgentTurnState` carries an
/// associated value, so turns are decoded through a string-based DTO.
enum FixtureLoader {
    struct BriefTurnsFixture: Decodable {
        let conversationID: UUID
        let turns: [TurnDTO]
        let messages: [LumiChatMessage]
    }

    struct TurnDTO: Decodable {
        let id: UUID
        let state: String
        let startedAt: Date
        let endedAt: Date?
        let inputTokenCount: Int
        let outputTokenCount: Int
        let toolCallCount: Int
        let toolCallCompletedCount: Int
        let title: String?
        let errorMessage: String?
    }

    struct MixedMessagesFixture: Decodable {
        let conversationID: UUID
        let messages: [LumiChatMessage]
    }

    struct AskUserFixture: Decodable {
        let conversationID: UUID
        let turn: TurnDTO
        let suspension: AgentTurnSuspension
        let messages: [LumiChatMessage]
    }

    static func briefTurns() throws -> BriefTurnsFixture {
        try decode("brief-turns.json")
    }

    static func mixedMessages() throws -> MixedMessagesFixture {
        try decode("mixed-messages.json")
    }

    static func askUser() throws -> AskUserFixture {
        try decode("ask-user.json")
    }

    static func markdownShowcase() throws -> String {
        try String(contentsOf: fixtureURL("markdown-showcase.md"), encoding: .utf8)
    }

    static func turnRecord(from dto: TurnDTO, conversationID: UUID) -> AgentTurnRecord {
        let state: AgentTurnState
        switch dto.state.lowercased() {
        case "idle": state = .idle
        case "running": state = .running
        case "completed": state = .completed
        case "failed": state = .failed
        case "cancelled": state = .cancelled
        case "suspended":
            state = .suspended(AgentTurnSuspension(
                suspensionID: UUID().uuidString,
                conversationID: conversationID,
                kind: "ask_user",
                payload: ""
            ))
        default:
            fatalError("Unknown turn state in fixture: \(dto.state)")
        }
        return AgentTurnRecord(
            id: dto.id,
            conversationID: conversationID,
            parentTurnID: nil,
            triggerMessageID: nil,
            state: state,
            startedAt: dto.startedAt,
            endedAt: dto.endedAt,
            inputTokenCount: dto.inputTokenCount,
            outputTokenCount: dto.outputTokenCount,
            toolCallCount: dto.toolCallCount,
            toolCallCompletedCount: dto.toolCallCompletedCount,
            title: dto.title,
            errorMessage: dto.errorMessage
        )
    }

    // MARK: - Private

    private static func decode<T: Decodable>(_ name: String) throws -> T {
        let data = try Data(contentsOf: fixtureURL(name))
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private static func fixtureURL(_ name: String) -> URL {
        // FixtureLoader.swift lives at Tests/Support/FixtureLoader.swift.
        let testsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Support
            .deletingLastPathComponent() // Tests
        return testsDir
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }
}
