import Combine
import Foundation
import KitAgentTool
import ProviderMessage
import SwiftUI
import Testing
@testable import ProviderMessageRendering

@MainActor
struct ProviderMessageRenderingTests {
    @Test("消息渲染器注册、替换和移除会发布观察事件")
    func messageRendererChangesAreObservable() {
        let provider = DefaultMessageRenderingProviding()
        var changeCount = 0
        let cancellable = provider.objectWillChange.sink { _ in
            changeCount += 1
        }

        provider.register(makeMessageRenderer(id: "plain", order: 1))
        #expect(provider.allRenderers.map(\.id) == ["plain"])
        #expect(changeCount > 0)

        let countAfterRegister = changeCount
        provider.register(makeMessageRenderer(id: "plain", order: 2))
        #expect(provider.allRenderers.map(\.id) == ["plain"])
        #expect(provider.allRenderers[0].order == 2)
        #expect(changeCount > countAfterRegister)

        let countAfterReplace = changeCount
        provider.unregister(id: "plain")
        #expect(provider.allRenderers.isEmpty)
        #expect(changeCount > countAfterReplace)

        withExtendedLifetime(cancellable) {}
    }

    @Test("ToolCall 渲染器注册、替换和移除会发布观察事件")
    func toolCallRendererChangesAreObservable() {
        let provider = DefaultToolCallRenderingProviding()
        var changeCount = 0
        let cancellable = provider.objectWillChange.sink { _ in
            changeCount += 1
        }

        provider.register(LowPriorityToolCallRenderer())
        #expect(provider.allRenderers.map { type(of: $0).id } == ["shell"])
        #expect(changeCount > 0)

        let countAfterRegister = changeCount
        provider.register(HighPriorityToolCallRenderer())
        #expect(provider.allRenderers.map { type(of: $0).id } == ["shell"])
        #expect(type(of: provider.allRenderers[0]).priority == 2)
        #expect(changeCount > countAfterRegister)

        let countAfterReplace = changeCount
        provider.unregister(id: "shell")
        #expect(provider.allRenderers.isEmpty)
        #expect(changeCount > countAfterReplace)

        withExtendedLifetime(cancellable) {}
    }

    private func makeMessageRenderer(id: String, order: Int) -> MessageRendererItem {
        MessageRendererItem(id: id, order: order) { _, _ in
            AnyView(EmptyView())
        }
    }
}

private struct LowPriorityToolCallRenderer: ToolCallRowRenderer {
    static var id: String { "shell" }
    static var priority: Int { 1 }

    func canRender(toolCall: ToolCall) -> Bool { true }

    @MainActor
    func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        AnyView(EmptyView())
    }
}

private struct HighPriorityToolCallRenderer: ToolCallRowRenderer {
    static var id: String { "shell" }
    static var priority: Int { 2 }

    func canRender(toolCall: ToolCall) -> Bool { true }

    @MainActor
    func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        AnyView(EmptyView())
    }
}
