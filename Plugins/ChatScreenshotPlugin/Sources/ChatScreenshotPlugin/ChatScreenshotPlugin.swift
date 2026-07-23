import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// Chat Screenshot Plugin
///
/// 提供区域截图能力,流程:
/// 1. 用户在 ChatActionBar 点击 📷 按钮,或按 ⌘⇧S
/// 2. 通知 `.lumiCaptureScreenshot` 被 post
/// 3. `triggerCapture` 调 `ScreenCaptureService` 抓全屏
/// 4. `ChatScreenshotState.startSelection` 创建 overlay,等待用户拖选
/// 5. 用户松手 → `onComplete(Data?)` 拿到 JPEG 字节
/// 6. 经 `ScreenCaptureImageProcessor.makeAttachment` 包装成 `LumiImageAttachment`
/// 7. `kernel.messageSend.addAttachment(attachment)` 注入附件挂起池
/// 8. `ChatAttachmentPreviewPlugin` 立即渲染缩略图
@MainActor
public final class ChatScreenshotPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "📸"

    public let id = "com.coffic.lumi.plugin.chat-screenshot"
    public let name = "Chat Screenshot"
    public let order = 81
    public let policy: LumiPluginPolicy = .alwaysOn

    private weak var kernel: LumiKernel?
    private var notificationObserver: NSObjectProtocol?

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        self.kernel = kernel
    }

    public func onReady(kernel: LumiKernel) async throws {
        // 1. 监听截图触发通知
        let token = NotificationCenter.default.addObserver(
            forName: .lumiCaptureScreenshot,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleCaptureTrigger(kernel: kernel)
            }
        }
        notificationObserver = token

        // 2. 注册 ⌘⇧S 全局命令
        kernel.command?.registerCommand(
            menu: "Chat",
            item: CommandItem(
                id: "\(id).capture",
                title: String(localized: "Capture Screenshot", bundle: .module),
                shortcut: "s",
                modifiers: [.command, .shift]
            ) {
                NotificationCenter.default.post(name: .lumiCaptureScreenshot, object: nil)
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)ChatScreenshotPlugin onReady 完成")
        }
    }

    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] {
        [
            ChatSectionActionBarItem(id: "\(id).button") {
                ChatScreenshotButtonView(kernel: kernel)
            }
        ]
    }

    // MARK: - 截图流程

    @MainActor
    private func handleCaptureTrigger(kernel: LumiKernel) async {
        guard ScreenCapturePermissionPrompter.ensurePermission() else {
            ScreenCapturePermissionPrompter.presentAlert(openSettingsOnConfirm: true)
            return
        }

        let screenshot: ScreenCaptureService.Result
        do {
            screenshot = try await ScreenCaptureService.captureAllScreens()
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)抓全屏失败: \(error.localizedDescription)")
            }
            return
        }

        ChatScreenshotState.shared.startSelection(
            image: screenshot.image,
            captureFrame: screenshot.frame,
            onComplete: { [weak kernel] cropped in
                guard let cropped else { return }
                let attachment = ScreenCaptureImageProcessor.makeAttachment(from: cropped)
                kernel?.messageSender?.addAttachment(attachment)
                if Self.verbose {
                    Self.logger.info("\(Self.t)截图完成 ➡️ 已加入附件池")
                }
            }
        )
    }

    // MARK: - LumiPlugin stubs

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
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}

// MARK: - Logger

extension ChatScreenshotPlugin {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.chat-screenshot"
    )
    nonisolated static let verbose = false
}
