import CoreGraphics
import KernelCore
import os
import ProviderMessage
import ProviderMessageSender

/// 截图流程编排：权限检查 → 全屏抓取 → 遮罩拖选 → 编码 → 加入图片预览。
///
/// 由旧版 `ChatScreenshotPlugin.handleCaptureTrigger` 复刻而来，职责与 UI 解耦，
/// 便于按钮视图与后续命令入口复用同一流程。
@MainActor
enum ScreenshotFlowRunner {
    /// 启动一次完整截图流程（可安全重复调用，进行中会自然忽略）。
    static func run(kernel: KernelCoreContainer) async {
        guard ScreenCapturePermissionPrompter.ensurePermission() else {
            ScreenCapturePermissionPrompter.presentAlert(openSettingsOnConfirm: true)
            return
        }

        let result: ScreenCaptureService.Result
        do {
            result = try await ScreenCaptureService.captureAllScreens()
        } catch {
            logger.error("抓全屏失败: \(error.localizedDescription, privacy: .public)")
            return
        }

        // 遮罩拖选；完成回调拿到裁剪后的 CGImage。
        ChatScreenshotState.shared.startSelection(
            image: result.image,
            captureFrame: result.frame
        ) { [weak kernel] cropped in
            guard let kernel, let cropped else { return }
            insert(kernel: kernel, image: cropped)
        }
    }

    // MARK: - 私有

    /// 将裁剪结果编码为图片附件，加入发送器挂起池供输入框预览。
    private static func insert(kernel: KernelCoreContainer, image: CGImage) {
        guard let sender = kernel.resolveProvider((any MessageSendingProviding).self) else {
            logger.error("Failed to resolve MessageSendingProviding from kernel")
            return
        }

        do {
            let attachment = try ScreenshotFileWriter.makeAttachment(image)
            sender.addImageAttachment(attachment)
            logger.info("截图完成 ➡️ 已加入图片预览: \(attachment.fileName ?? "screenshot", privacy: .public)")
        } catch {
            logger.error("截图编码失败: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Logger

extension ScreenshotFlowRunner {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.chat-screenshot.flow"
    )
}
