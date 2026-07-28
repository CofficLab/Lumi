import XCTest
import LumiKernel
@testable import ConversationSpeedPlugin

final class ConversationSpeedPluginTests: XCTestCase {
    func testSpeedHistoryUsesChronologicalMessagesWithPerformanceData() throws {
        let conversationID = UUID()
        let later = Date(timeIntervalSince1970: 300)
        let earlier = Date(timeIntervalSince1970: 100)

        let messages = [
            LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "later",
                createdAt: later,
                outputTokenCount: 40,
                streamingDurationMs: 2_000
            ),
            LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "missing speed",
                createdAt: Date(timeIntervalSince1970: 200)
            ),
            LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "earlier",
                createdAt: earlier,
                metadata: [
                    "outputTokens": "30",
                    "streamingDurationMs": "1000"
                ]
            )
        ]

        let samples = ConversationSpeedSample.samples(from: messages)

        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples.map(\.index), [0, 1])
        XCTAssertEqual(samples.map(\.message.content), ["earlier", "later"])
        XCTAssertEqual(samples.map(\.tokensPerSecond), [30, 20])
        XCTAssertEqual(ConversationSpeedSample.averageTokensPerSecond(from: samples), 25)
        XCTAssertNil(ConversationSpeedSample.averageTokensPerSecond(from: []))
    }
}
