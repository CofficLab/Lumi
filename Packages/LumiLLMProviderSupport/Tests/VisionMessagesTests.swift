import XCTest
import LLMKit
import LumiCoreKit
@testable import LumiLLMProviderSupport

final class LumiVisionMessageSupportTests: XCTestCase {
    func testPreparedMessagesAttachRequestImagesToLastUserMessage() throws {
        let conversationID = UUID()
        let attachment = LumiImageAttachment(
            mimeType: "image/png",
            base64Data: Data([0x01, 0x02]).base64EncodedString()
        )
        let request = LumiLLMRequest(
            messages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "earlier"),
                LumiChatMessage(conversationID: conversationID, role: .assistant, content: "ok"),
                LumiChatMessage(conversationID: conversationID, role: .user, content: "with image"),
            ],
            model: "gpt-4o",
            imageAttachments: [attachment]
        )

        let prepared = LumiVisionMessageSupport.preparedMessages(for: request)
        let userMessages = prepared.filter { $0.role == .user }

        XCTAssertEqual(userMessages.count, 2)
        XCTAssertTrue(userMessages[0].images.isEmpty)
        XCTAssertEqual(userMessages[1].images.count, 1)
        XCTAssertEqual(userMessages[1].images[0].mimeType, "image/png")
    }
}
