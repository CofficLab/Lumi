import AppKit
import Foundation
import LumiKernel
import LumiUI
import MarkdownKit
import SwiftUI
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

@MainActor
@Test func coreErrorRendererDefersToXiaomiRenderKind() {
    let renderers = MessageRendererPlugin.messageRenderers(context: testContext)
    let conversationID = UUID()
    let xiaomiAPIKeyError = LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: "",
        providerID: "xiaomi-api",
        isError: true,
        renderKind: "xiaomi-api-key-missing"
    )

    #expect(renderers.first { $0.id == "core-error-message" }?.canRender(xiaomiAPIKeyError) == false)
}

private var testContext: LumiPluginContext {
    LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
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
