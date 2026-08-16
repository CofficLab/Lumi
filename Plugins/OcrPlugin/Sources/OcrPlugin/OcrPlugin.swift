import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// OCR 文字识别插件。
///
/// 通过 `ocr_image` Agent 工具，对本地图片文件做文字识别并把提取的文本送回对话。
/// 基于 macOS Vision 框架，**纯本地、离线、不调用任何第三方 API、不产生网络请求**。
/// 架构与 `ShowImagePlugin` / `DocxReadPlugin` 同构：一个 `LumiAgentTool` 暴露给 LLM，
/// 识别逻辑封装在无内核依赖的 `OcrEngine` 中以便单测。
@MainActor
public final class OcrPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🔤"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.ocr"
    )

    public let id = "com.coffic.lumi.plugin.ocr"
    public var name: String { OcrLocalization.string("OCR", "OCR 文字识别") }
    public var pluginDescription: String {
        OcrLocalization.string(
            "Recognize text in local image files using on-device macOS Vision (fully offline).",
            "使用 macOS Vision 识别本地图片中的文字（完全离线，不联网）。"
        )
    }

    public let order = 286
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // 无需注册核心服务；工具在 agentTools(kernel:) 中按需返回。
    }

    public func onReady(kernel: KernelLumi) async throws {
        // 依赖其他服务的异步初始化在此进行；本插件目前无需额外处理。
    }

    // MARK: - Contributions

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [OcrImageTool()]
    }

    // MARK: - LumiPlugin stubs（无默认实现的贡献点需显式置空）

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(OcrAboutView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
