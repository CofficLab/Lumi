import LumiKernel
import SwiftUI

/// Chat File Attachment Plugin
///
/// 在 ChatActionBar 上提供一个「添加文件」按钮(回形针图标),位于截图按钮右侧。
/// 点击后弹出文件选择器(`.fileImporter`),用户选择任意文件后:
/// - 图片文件(png/jpg/gif/webp/bmp/tiff/heic)→ 构造 `LumiImageAttachment` 进入图片挂起池
///   (复用现有的多模态管线,视觉/发送零改动)。
/// - 非图片文件 → 构造 `LumiFileAttachment` 进入文件挂起池;文本类文件正文在发送时
///   注入用户消息文本,二进制文件仅作可见 chip + 占位标注。
///
/// - 位置:`order = 81`,与 `ChatScreenshotPlugin` 同组,排在它之后(模型选择 82、输入框 83)。
/// - 策略:`.alwaysOn`。
/// - 不持有任何本地状态,选中的文件直接交给 `MessageSending` 挂起池。
@MainActor
public final class ChatFileAttachmentPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-file-attachment"
    public let name = "Chat File Attachment"
    public let order = 81
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] {
        [
            ChatSectionActionBarItem(id: "\(id).button") {
                ChatFileAttachmentButton(kernel: kernel)
            }
        ]
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
