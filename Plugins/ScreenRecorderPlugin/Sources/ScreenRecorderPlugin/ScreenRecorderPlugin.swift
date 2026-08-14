import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// 屏幕录制插件。
///
/// 通过自然语言对话即可录制任意 app 的使用流程（含可选声音），结束后自动把视频
/// 输出到下载目录。架构：一个跨多轮对话存活的 `RecordingSessionManager` 单例，
/// 驱动基于 `SCStream + AVAssetWriter` 的录制引擎；通过三个 `LumiAgentTool`
/// （`start_recording` / `stop_recording` / `list_recordable_apps`）暴露给 LLM；
/// 录制期间用一个系统级置顶 `NSPanel` 浮层指示器反馈状态。架构与 `MindMapPlugin`
/// 同构。
@MainActor
public final class ScreenRecorderPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🎥"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.screen-recorder"
    )

    public let id = "com.coffic.lumi.plugin.screen-recorder"
    public var name: String { ScreenRecorderLocalization.string("Screen Recorder", "屏幕录制") }
    public var pluginDescription: String {
        ScreenRecorderLocalization.string(
            "Record any app's usage flow to a video file in your Downloads folder, driven entirely by chat.",
            "通过对话录制任意 app 的使用流程，结束后把视频输出到下载目录。"
        )
    }

    public let order = 285
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        ScreenRecorderRuntime.configure(kernel: kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        // 依赖其他服务的异步初始化在此进行；本插件目前无需额外处理。
    }

    // MARK: - Contributions

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            StartRecordingTool(),
            StopRecordingTool(),
            ListRecordableAppsTool(),
        ]
    }

    public func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        await ScreenRecorderWillSendToLLMHook().execute(kernel: kernel, messages: messages)
    }

    public func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] {
        [
//            LumiPromptSuggestion(
//                id: "\(id).record-flow",
//                title: ScreenRecorderLocalization.string("Record an app's usage flow", "录制一个 app 的使用流程"),
//                prompt: ScreenRecorderLocalization.string(
//                    "Help me record an app's usage flow into a video in my Downloads folder.",
//                    "帮我录制一个 app 的使用流程，结束后把视频保存到下载目录。"
//                ),
//                systemImage: "record.circle"
//            ),
        ]
    }

    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: "\(id).settings",
                title: ScreenRecorderLocalization.string("Screen Recorder", "屏幕录制"),
                systemImage: "record.circle",
                order: order
            ) {
                ScreenRecorderSettingsView()
            },
        ]
    }

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
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
