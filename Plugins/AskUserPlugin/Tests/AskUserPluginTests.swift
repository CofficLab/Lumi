import Foundation
import LumiCoreKit
import Testing
@testable import AskUserPlugin

// MARK: - Plugin Info Tests

@Suite @MainActor struct AskUserPluginInfoTests {
    
    @Test func pluginId() {
        #expect(AskUserPlugin.info.id == "plugin-ask-user")
    }
    
    @Test func pluginDisplayNameIsNotEmpty() {
        #expect(!AskUserPlugin.info.displayName.isEmpty)
    }
    
    @Test func pluginDescriptionIsNotEmpty() {
        #expect(!AskUserPlugin.info.description.isEmpty)
    }
    
    @Test func pluginOrder() {
        #expect(AskUserPlugin.info.order == 100)
    }
}

// MARK: - Plugin Properties Tests

@Suite @MainActor struct AskUserPluginPropertiesTests {
    
    @Test func pluginPolicyIsAlwaysOn() {
        #expect(AskUserPlugin.policy == .alwaysOn)
    }
    
    @Test func pluginCategoryIsGeneral() {
        #expect(AskUserPlugin.category == .general)
    }
    
    @Test func pluginIconName() {
        #expect(AskUserPlugin.iconName == "questionmark.circle.fill")
    }
}

// MARK: - Agent Tools Tests

@Suite @MainActor struct AskUserPluginAgentToolsTests {
    
    @Test func agentToolsReturnsOneTool() {
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )
        let tools = AskUserPlugin.agentTools(context: context)
        #expect(tools.count == 1)
    }

    @Test func agentToolsReturnsAskUserTool() {
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )
        let tools = AskUserPlugin.agentTools(context: context)
        #expect(tools.first?.name == "ask_user")
    }
}

// MARK: - Configure Ask User Resume Tests

@Suite(.serialized) @MainActor struct AskUserPluginConfigureResumeTests {
    
    @Test func configureAskUserResumeSetsBridgeHandler() {
        // Given
        let mockResumer = MockAskUserResuming()
        
        // When
        AskUserPlugin.configureAskUserResume(mockResumer)
        
        // Then
        #expect(AskUserBridge.shared.resumeHandler != nil)
        
        // Cleanup
        AskUserBridge.shared.resumeHandler = nil
    }
    
    @Test func configureAskUserResumeHandlerCallsResumer() async throws {
        // Given
        let mockResumer = MockAskUserResuming()
        AskUserPlugin.configureAskUserResume(mockResumer)
        
        let conversationId = UUID().uuidString
        let toolCallId = "test-tool-call"
        let answer = "Yes"
        
        // When
        AskUserBridge.shared.resume(conversationId: conversationId, toolCallId: toolCallId, answer: answer)
        
        // Wait for async Task to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        #expect(mockResumer.lastConversationID?.uuidString == conversationId)
        #expect(mockResumer.lastToolCallID == toolCallId)
        #expect(mockResumer.lastAnswer == answer)
        
        // Cleanup
        AskUserBridge.shared.resumeHandler = nil
    }
    
    @Test func configureAskUserResumeIgnoresInvalidUUID() async throws {
        // Given
        let mockResumer = MockAskUserResuming()
        AskUserPlugin.configureAskUserResume(mockResumer)
        
        // When - invalid UUID string
        AskUserBridge.shared.resume(conversationId: "not-a-valid-uuid", toolCallId: "test-tool-call", answer: "Yes")
        
        // Wait for async Task to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then - resumer should not be called
        #expect(mockResumer.lastConversationID == nil)
        
        // Cleanup
        AskUserBridge.shared.resumeHandler = nil
    }
}

// MARK: - Mock Resumer

@MainActor
private final class MockAskUserResuming: LumiAskUserResuming {
    var lastConversationID: UUID?
    var lastToolCallID: String?
    var lastAnswer: String?
    
    func resumeAfterAskUser(conversationID: UUID, toolCallID: String, answer: String) async {
        lastConversationID = conversationID
        lastToolCallID = toolCallID
        lastAnswer = answer
    }
}
