import Foundation
import Testing
@testable import LumiChatKit

@MainActor
@Test func setToolProgressFormatsElapsedSeconds() {
    let state = ConversationStatusState()
    let conversationID = UUID()

    state.setToolProgress(
        conversationID: conversationID,
        toolName: "run_command",
        elapsedSeconds: 12,
        outputPreview: nil
    )

    #expect(state.statusMessage(for: conversationID)?.content == "run_command（12s）")
}

@MainActor
@Test func setToolProgressIncludesOutputPreviewWhenProvided() {
    let state = ConversationStatusState()
    let conversationID = UUID()

    state.setToolProgress(
        conversationID: conversationID,
        toolName: "run_command",
        elapsedSeconds: 3,
        outputPreview: "Building..."
    )

    #expect(
        state.statusMessage(for: conversationID)?.content
            == "run_command（3s，最近输出：Building...）"
    )
}

@MainActor
@Test func setToolCompletedFormatsDuration() {
    let state = ConversationStatusState()
    let conversationID = UUID()

    state.setToolCompleted(
        conversationID: conversationID,
        toolName: "run_command",
        elapsedSeconds: 8
    )

    #expect(state.statusMessage(for: conversationID)?.content == "run_command（8s）")
}
