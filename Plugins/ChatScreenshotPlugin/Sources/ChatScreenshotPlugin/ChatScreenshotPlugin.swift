import KernelLumi
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
/// 8. `ConversationAttachmentPlugin` 立即渲染缩略图
@MainActor
public final class ChatScreenshotPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "📸"

    public let id = "com.coffic.lumi.plugin.chat-screenshot"
    public var name: String {
        LumiPluginLocalization.string("Chat Screenshot", bundle: .module)
    }
    public let order = 81
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    private weak var kernel: KernelLumi?
    private var notificationObserver: NSObjectProtocol?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        self.kernel = kernel
    }

    public func onReady(kernel: KernelLumi) async throws {
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

        if Self.verbose {
            Self.logger.info("\(Self.t)ChatScreenshotPlugin onReady 完成")
        }
    }

    public func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup] {
        [
            CommandMenuGroup(
                id: "\(id).commands",
                name: name,
                items: [
                    CommandItem(
                        id: "\(id).capture",
                        title: String(localized: "Capture Screenshot", bundle: .module),
                        shortcut: "s",
                        modifiers: [.command, .shift]
                    ) {
                        NotificationCenter.default.post(name: .lumiCaptureScreenshot, object: nil)
                    },
                ],
                placement: .toolbar
            ),
        ]
    }

    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] {
        [
            ChatSectionActionBarItem(id: "\(id).button") {
                ChatScreenshotButtonView()
            }
        ]
    }

    // MARK: - 截图流程

    @MainActor
    private func handleCaptureTrigger(kernel: KernelLumi) async {
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

// MARK: - Logger

extension ChatScreenshotPlugin {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.chat-screenshot"
    )
    nonisolated static let verbose = false
}
