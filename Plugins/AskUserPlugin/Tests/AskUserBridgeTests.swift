import Foundation
import LumiCoreKit
import Testing
@testable import AskUserPlugin

// MARK: - Resume Tests

@Suite(.serialized) @MainActor struct AskUserBridgeResumeTests {
    
    @Test func resumeHandlerCanBeSet() {
        // Given
        let bridge = AskUserBridge.shared
        var handlerCalled = false
        
        // When
        bridge.resumeHandler = { _, _, _ in
            handlerCalled = true
        }
        
        // Then
        #expect(bridge.resumeHandler != nil)
        
        // Cleanup
        bridge.resumeHandler = nil
    }
    
    @Test func resumeCallsHandlerWhenSet() {
        // Given
        let bridge = AskUserBridge.shared
        var receivedConversationId: String?
        var receivedToolCallId: String?
        var receivedAnswer: String?
        
        bridge.resumeHandler = { conversationId, toolCallId, answer in
            receivedConversationId = conversationId
            receivedToolCallId = toolCallId
            receivedAnswer = answer
        }
        
        // When
        let conversationId = UUID().uuidString
        let toolCallId = "test-tool-call-id"
        let answer = "Yes"
        
        bridge.resume(conversationId: conversationId, toolCallId: toolCallId, answer: answer)
        
        // Then
        #expect(receivedConversationId == conversationId)
        #expect(receivedToolCallId == toolCallId)
        #expect(receivedAnswer == answer)
        
        // Cleanup
        bridge.resumeHandler = nil
    }
    
    @Test func resumeDoesNotCrashWhenHandlerNotSet() {
        // Given
        let bridge = AskUserBridge.shared
        bridge.resumeHandler = nil
        
        // When & Then - should not crash
        bridge.resume(conversationId: "conv-123", toolCallId: "tool-456", answer: "No")
    }
    
    @Test func resumeHandlerCanBeCleared() {
        // Given
        let bridge = AskUserBridge.shared
        bridge.resumeHandler = { _, _, _ in }
        
        // When
        bridge.resumeHandler = nil
        
        // Then
        #expect(bridge.resumeHandler == nil)
    }
    
    @Test func resumeHandlerCanBeReplaced() {
        // Given
        let bridge = AskUserBridge.shared
        var firstHandlerCalled = false
        var secondHandlerCalled = false
        
        bridge.resumeHandler = { _, _, _ in
            firstHandlerCalled = true
        }
        
        // When - replace handler
        bridge.resumeHandler = { _, _, _ in
            secondHandlerCalled = true
        }
        
        bridge.resume(conversationId: "conv", toolCallId: "tool", answer: "answer")
        
        // Then
        #expect(!firstHandlerCalled)
        #expect(secondHandlerCalled)
        
        // Cleanup
        bridge.resumeHandler = nil
    }
}

// MARK: - Shared Instance Tests

@Suite @MainActor struct AskUserBridgeSharedInstanceTests {
    
    @Test func sharedInstanceExists() {
        // Given & When & Then
        #expect(AskUserBridge.shared != nil)
    }
    
    @Test func sharedInstanceIsSameObject() {
        // Given
        let bridge1 = AskUserBridge.shared
        let bridge2 = AskUserBridge.shared
        
        // Then
        #expect(bridge1 === bridge2)
    }
}
