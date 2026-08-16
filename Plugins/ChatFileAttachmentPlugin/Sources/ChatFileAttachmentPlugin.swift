import KernelLumi
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
    public var name: String {
        LumiPluginLocalization.string("Chat File Attachment", bundle: .module)
    }
    public let order = 81
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {}

    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] {
        [
            ChatSectionActionBarItem(id: "\(id).button") {
                ChatFileAttachmentButton(kernel: kernel)
            }
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
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
