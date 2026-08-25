import Foundation
import SwiftUI
import Testing
@testable import KitAgentTool

private struct StubRenderer: ToolCallRowRenderer {
    static let id = "stub"
    let accepts: Bool
    init(accepts: Bool = true) { self.accepts = accepts }
    func canRender(toolCall: ToolCall) -> Bool { accepts }
    func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView { AnyView(EmptyView()) }
}

private struct HighPriorityRenderer: ToolCallRowRenderer {
    static let id = "high"
    static let priority = 100
    func canRender(toolCall: ToolCall) -> Bool { true }
    func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView { AnyView(EmptyView()) }
}

private struct LowPriorityRenderer: ToolCallRowRenderer {
    static let id = "low"
    static let priority = 1
    func canRender(toolCall: ToolCall) -> Bool { true }
    func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView { AnyView(EmptyView()) }
}

@MainActor
struct ToolCallRowMessageContextTests {
    @Test
    func initDefaultsVerbosityToNil() {
        let context = ToolCallRowMessageContext(
            conversationId: UUID(), assistantMessageId: UUID()
        )
        #expect(context.verbosityRawValue == nil)
    }

    @Test
    func initKeepsVerbosity() {
        let context = ToolCallRowMessageContext(
            conversationId: UUID(), assistantMessageId: UUID(), verbosityRawValue: "verbose"
        )
        #expect(context.verbosityRawValue == "verbose")
    }
}

@MainActor
struct ToolCallRowRendererRegistryTests {
    @Test
    func defaultPriorityIsZero() {
        #expect(StubRenderer.priority == 0)
        #expect(HighPriorityRenderer.priority == 100)
    }

    @Test
    func findRendererPrefersHigherPriority() {
        let registry = ToolCallRowRendererRegistry()
        registry.register(LowPriorityRenderer())
        registry.register(HighPriorityRenderer())
        let toolCall = ToolCall(
            id: UUID().uuidString,
            name: "shell",
            arguments: "{}"
        )
        let renderer = registry.findRenderer(for: toolCall)
        #expect((renderer as? HighPriorityRenderer) != nil)
    }

    @Test
    func registerSameIDIgnoresPreviousInstance() {
        let registry = ToolCallRowRendererRegistry()
        registry.register(StubRenderer(accepts: true))
        registry.register(StubRenderer(accepts: false))
        let toolCall = ToolCall(
            id: UUID().uuidString,
            name: "shell",
            arguments: "{}"
        )
        // 后注册的实例替换先前的（accepts = false）
        #expect(registry.findRenderer(for: toolCall) == nil)
    }

    @Test
    func findRendererReturnsNilWhenNoneAccepts() {
        let registry = ToolCallRowRendererRegistry()
        registry.register(StubRenderer(accepts: false))
        let toolCall = ToolCall(
            id: UUID().uuidString,
            name: "shell",
            arguments: "{}"
        )
        #expect(registry.findRenderer(for: toolCall) == nil)
    }
}
