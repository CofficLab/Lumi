import AppKit
import Foundation
import LumiKernel
import LumiUI
import MarkdownKit
import SwiftUI
import Testing
@testable import MessageRendererPlugin

@MainActor
@Test func pluginRegistersCoreRenderers() async throws {
    let renderers = try await bootedRenderers()
    #expect(renderers.map(\.id).contains("core-user-message"))
    #expect(renderers.map(\.id).contains("core-assistant-message"))
    #expect(renderers.map(\.id).contains("core-tool-message"))
    #expect(renderers.map(\.id).contains("core-error-message"))
}

@MainActor
@Test func coreRenderersMatchExpectedRoles() async throws {
    let renderers = try await bootedRenderers()
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
@Test func coreErrorRendererMatchesProviderSpecificRenderKind() async throws {
    let renderers = try await bootedRenderers()
    let conversationID = UUID()
    let zhipuError = LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: "failed",
        providerID: "zhipu",
        isError: true,
        renderKind: "zhipu-http-403"
    )

    #expect(renderers.first { $0.id == "core-error-message" }?.canRender(zhipuError) == true)
}

@MainActor
@Test func coreErrorRendererMatchesGenericErrors() async throws {
    let renderers = try await bootedRenderers()
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
@Test func coreErrorRendererMatchesAliyunRenderKind() async throws {
    let renderers = try await bootedRenderers()
    let conversationID = UUID()
    let aliyunError = LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: "failed",
        providerID: "aliyun",
        isError: true,
        renderKind: "aliyun-http-403"
    )

    #expect(renderers.first { $0.id == "core-error-message" }?.canRender(aliyunError) == true)
}

@MainActor
@Test func coreErrorRendererMatchesXiaomiRenderKind() async throws {
    let renderers = try await bootedRenderers()
    let conversationID = UUID()
    let xiaomiAPIKeyError = LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: "",
        providerID: "xiaomi-api",
        isError: true,
        renderKind: "xiaomi-api-key-missing"
    )

    #expect(renderers.first { $0.id == "core-error-message" }?.canRender(xiaomiAPIKeyError) == true)
}

@MainActor
private func bootedRenderers() async throws -> [LumiMessageRendererItem] {
    let kernel = LumiKernel()
    try await MessageRendererOnBootHook().execute(kernel)
    return kernel.messageRendererManager?.allMessageRenderers() ?? []
}

// MARK: - Assistant markdown contrast

/// 复现：VS Code 深色 + macOS 浅色系统时，助手正文用 Markdown 默认 `.primary`（跟系统走），
/// 而聊天区背景跟 chrome 主题走，导致深字深底。
@MainActor
@Test func assistantMarkdownStandardThemeLeavesTextColorUnset() {
    #expect(MarkdownTheme.standard.textColor == nil)
}

@MainActor
@Test func assistantMarkdownBodyFailsContrastOnForcedDarkChatSurfaceUnderLightSystem() {
    let chrome = ForcedDarkChatChromeFixture()
    let ui = ChromeToUIThemeAdapter(chrome: chrome)
    let lightAppearance = NSAppearance(named: .aqua)!

    let defaultReadable = AssistantMarkdownContrastTestSupport.hasSufficientContrast(
        text: Color.primary,
        surface: ui.surface,
        systemAppearance: lightAppearance
    )
    #expect(!defaultReadable, "Default Markdown foreground should expose the regression on forced-dark chrome")

    let chatTheme = ChatMarkdownTheme.make(from: ui)
    let chatReadable = AssistantMarkdownContrastTestSupport.hasSufficientContrast(
        text: chatTheme.textColor!,
        surface: ui.surface,
        systemAppearance: lightAppearance
    )
    #expect(chatReadable, "Chat markdown theme should follow chrome text colors")
}

private struct ForcedDarkChatChromeFixture: LumiAppChromeTheme {
    let identifier = "forced-dark-chat"
    let displayName = "Forced Dark Chat"
    let compactName = "Dark"
    let description = "VS Code dark-like chrome for chat contrast tests"
    let iconName = "bubble.left.and.bubble.right"
    let iconColor = Color(hex: "007ACC")
    let appearanceKind: ThemeAppearanceKind = .dark

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (Color(hex: "007ACC"), Color(hex: "C586C0"), Color(hex: "D7BA7D"))
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (Color(hex: "1E1E1E"), Color(hex: "252526"), Color(hex: "2D2D2D"))
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (.blue, .blue, .blue)
    }

    func workspaceTextColor() -> Color { Color(hex: "CCCCCC") }
}

private enum AssistantMarkdownContrastTestSupport {
    static func perceptualLuminance(_ color: Color, appearance: NSAppearance) -> Double {
        let saved = NSAppearance.current
        NSAppearance.current = appearance
        defer { NSAppearance.current = saved }
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return 0 }
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
    }

    static func hasSufficientContrast(
        text: Color,
        surface: Color,
        systemAppearance: NSAppearance,
        minimumDelta: Double = 0.25
    ) -> Bool {
        abs(
            perceptualLuminance(text, appearance: systemAppearance)
                - perceptualLuminance(surface, appearance: systemAppearance)
        ) >= minimumDelta
    }
}

// MARK: - Default fallback renderer

/// 兜底渲染器 `core-default-markdown` 必须接住所有消息,
/// 否则 MessageRowView 会显示 "No renderer for message: xx"。
@MainActor
@Test func defaultFallbackRendererAlwaysMatches() async throws {
    let renderers = try await bootedRenderers()
    let fallback = try #require(renderers.first { $0.id == "core-default-markdown" })
    let conversationID = UUID()

    // 空 content 也要接住(之前的 bug:条件是 `!message.content.isEmpty` → 漏接)
    let empty = LumiChatMessage(conversationID: conversationID, role: .assistant, content: "")
    #expect(fallback.canRender(empty) == true)

    // 已有内容也要接住
    let plain = LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
    #expect(fallback.canRender(plain) == true)

    // 各种 role 都要接住
    for role in LumiChatMessageRole.allCases {
        let message = LumiChatMessage(conversationID: conversationID, role: role, content: "")
        #expect(fallback.canRender(message) == true, "fallback must match role=\(role.rawValue)")
    }

    // 端到端:manager 单独只注册 fallback 时,任意消息都能命中,
    // 模拟"没有任何更具体 renderer 接管"的真实场景。
    let manager = MessageRendererManager()
    manager.registerMessageRenderer(fallback)
    let matched = manager.renderer(for: empty)
    #expect(matched?.id == "core-default-markdown")
}

// MARK: - Preferred renderer ID (explicit routing)

@MainActor
@Test func preferredRendererIDOverridesCanRenderChain() throws {
    let manager = MessageRendererManager()

    // 注册两个渲染器:A 只匹配 .user;B 只匹配 .error。
    // 故意按 canRender 链 B 会被优先（高 order），用于下面验证 preferred 直接命中 A。
    let rendererA = LumiMessageRendererItem(
        id: "test-renderer-a",
        order: 10,
        canRender: { $0.role == .user },
        render: { _, _ in EmptyView() }
    )
    let rendererB = LumiMessageRendererItem(
        id: "test-renderer-b",
        order: 999,
        canRender: { $0.role == .user },
        render: { _, _ in EmptyView() }
    )
    manager.registerMessageRenderer(rendererA)
    manager.registerMessageRenderer(rendererB)

    // 1) 不带 preferred → 走原 canRender 链,order 大的 B 胜出
    let plain = LumiChatMessage(conversationID: UUID(), role: .user, content: "hi")
    let matchedPlain = manager.renderer(for: plain)
    #expect(matchedPlain?.id == "test-renderer-b")

    // 2) 带 preferredRendererID → 直接命中 A,无视 order 和 canRender
    let preferred = LumiChatMessage(
        conversationID: UUID(),
        role: .user,
        content: "hi",
        preferredRendererID: "test-renderer-a"
    )
    let matchedPreferred = manager.renderer(for: preferred)
    #expect(matchedPreferred?.id == "test-renderer-a")
}

@MainActor
@Test func preferredRendererIDFallsBackWhenRendererNotRegistered() throws {
    let manager = MessageRendererManager()
    let renderer = LumiMessageRendererItem(
        id: "test-only-renderer",
        order: 100,
        canRender: { $0.role == .user },
        render: { _, _ in EmptyView() }
    )
    manager.registerMessageRenderer(renderer)

    // preferredRendererID 指向一个**未注册**的 id → 应走原 canRender 链
    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .user,
        content: "hi",
        preferredRendererID: "does-not-exist"
    )
    let matched = manager.renderer(for: message)
    #expect(matched?.id == "test-only-renderer")
}

@MainActor
@Test func preferredRendererIDFallsBackAfterUnregister() throws {
    let manager = MessageRendererManager()
    let rendererA = LumiMessageRendererItem(
        id: "test-renderer-a",
        order: 10,
        canRender: { $0.role == .user },
        render: { _, _ in EmptyView() }
    )
    let rendererB = LumiMessageRendererItem(
        id: "test-renderer-b",
        order: 999,
        canRender: { $0.role == .user },
        render: { _, _ in EmptyView() }
    )
    manager.registerMessageRenderer(rendererA)
    manager.registerMessageRenderer(rendererB)

    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .user,
        content: "hi",
        preferredRendererID: "test-renderer-a"
    )

    // 1) A 注册时:preferred 命中 A
    #expect(manager.renderer(for: message)?.id == "test-renderer-a")

    // 2) A 被注销后:preferred 失效,走原 canRender 链,命中 B
    manager.unregisterMessageRenderer(id: "test-renderer-a")
    #expect(manager.renderer(for: message)?.id == "test-renderer-b")
}
