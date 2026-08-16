import CoreGraphics
import Foundation
import KernelCore
import os
import ProviderConversationInput
import ProviderStorage

/// 截图流程编排：权限检查 → 全屏抓取 → 遮罩拖选 → 落盘 → 插入输入框。
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

    /// 裁剪结果保存为 JPEG 文件，并把文件路径插入输入框。
    private static func insert(kernel: KernelCoreContainer, image: CGImage) {
        guard let storage = kernel.resolveProvider((any StorageProviding).self),
              let input = kernel.resolveProvider((any ConversationInputProviding).self) else {
            return
        }
        let directory = storage.pluginDataDirectory(for: "ChatScreenshot")
        do {
            let url = try ScreenshotFileWriter.write(image, to: directory)
            input.addToConversation(fileURLs: [url])
            logger.info("截图完成 ➡️ 已插入输入框: \(url.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("截图落盘失败: \(error.localizedDescription, privacy: .public)")
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
