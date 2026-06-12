import Foundation
import LumiCoreKit
import Testing
@testable import MessageRendererPlugin

@MainActor
@Test func pluginRegistersCoreRenderers() {
    let renderers = MessageRendererPlugin.messageRenderers(context: testContext)
    #expect(renderers.map(\.id).contains("core-user-message"))
    #expect(renderers.map(\.id).contains("core-assistant-message"))
    #expect(renderers.map(\.id).contains("core-tool-message"))
    #expect(renderers.map(\.id).contains("core-error-message"))
}

@MainActor
@Test func coreRenderersMatchExpectedRoles() {
    let renderers = MessageRendererPlugin.messageRenderers(context: testContext)
    let conversationID = UUID()
    let user = LumiChatMessage(conversationID: conversationID, role: .user, content: "hello")
    let assistant = LumiChatMessage(conversationID: conversationID, role: .assistant, content: "hi")
    let tool = LumiChatMessage(conversationID: conversationID, role: .tool, content: "ok")
    let error = LumiChatMessage(conversationID: conversationID, role: .error, content: "failed", isError: true)

    #expect(renderers.first { $0.id == "core-user-message" }?.canRender(user) == true)
    #expect(renderers.first { $0.id == "core-assistant-message" }?.canRender(assistant) == true)
    #expect(renderers.first { $0.id == "core-tool-message" }?.canRender(tool) == true)
    #expect(renderers.first { $0.id == "core-error-message" }?.canRender(error) == true)
}

@MainActor
@Test func coreErrorRendererDefersToZhipuRenderKind() {
    let renderers = MessageRendererPlugin.messageRenderers(context: testContext)
    let conversationID = UUID()
    let zhipuError = LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: "failed",
        providerID: "zhipu",
        isError: true,
        renderKind: "zhipu-http-403"
    )

    #expect(renderers.first { $0.id == "core-error-message" }?.canRender(zhipuError) == false)
}

@MainActor
@Test func coreErrorRendererMatchesGenericErrors() {
    let renderers = MessageRendererPlugin.messageRenderers(context: testContext)
    let conversationID = UUID()
    let error = LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: "failed",
        isError: true
    )

    #expect(renderers.first { $0.id == "core-error-message" }?.canRender(error) == true)
}

@MainActor
@Test func coreErrorRendererDefersToAliyunRenderKind() {
    let renderers = MessageRendererPlugin.messageRenderers(context: testContext)
    let conversationID = UUID()
    let aliyunError = LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: "failed",
        providerID: "aliyun",
        isError: true,
        renderKind: "aliyun-http-403"
    )

    #expect(renderers.first { $0.id == "core-error-message" }?.canRender(aliyunError) == false)
}

private var testContext: LumiPluginContext {
    LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
}
