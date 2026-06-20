import Foundation
import LumiCoreKit
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

@MainActor
@Test func applyStreamChunkReusesStableStatusRowID() {
    let state = ConversationStatusState()
    let conversationID = UUID()

    state.applyStreamChunk(
        conversationID: conversationID,
        chunk: LumiStreamChunk(content: "hel", eventTitle: "生成中")
    )
    let firstID = state.statusMessage(for: conversationID)?.id

    state.applyStreamChunk(
        conversationID: conversationID,
        chunk: LumiStreamChunk(content: "lo", eventTitle: "生成中")
    )
    let secondID = state.statusMessage(for: conversationID)?.id

    #expect(firstID != nil)
    #expect(firstID == secondID)
    #expect(state.statusMessage(for: conversationID)?.content == "生成中：hello")
}

@MainActor
@Test func applyStreamChunkTruncatesTailPreview() {
    let state = ConversationStatusState()
    let conversationID = UUID()
    let longChunk = String(repeating: "字", count: 50)

    state.applyStreamChunk(
        conversationID: conversationID,
        chunk: LumiStreamChunk(content: longChunk, eventTitle: "生成中")
    )

    let preview = state.statusMessage(for: conversationID)?.content ?? ""
    let tail = preview.split(separator: "：", maxSplits: 1).last.map(String.init) ?? ""
    #expect(tail.count == 20)
}

@MainActor
@Test func applyStreamChunkClearsBuffersWhenDone() {
    let state = ConversationStatusState()
    let conversationID = UUID()

    state.applyStreamChunk(
        conversationID: conversationID,
        chunk: LumiStreamChunk(content: "partial", isThinking: true, eventTitle: "思考中")
    )
    state.applyStreamChunk(
        conversationID: conversationID,
        chunk: LumiStreamChunk(isDone: true, eventTitle: "结束")
    )

    #expect(state.statusMessage(for: conversationID)?.content == "结束")
}
