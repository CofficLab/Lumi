import CoreGraphics
import Foundation
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
        // 权限未决定时这里会拉起系统授权弹窗，用户拒绝后才落到下面的设置引导。
        guard ScreenCapturePermissionPrompter.ensurePermission() else {
            ScreenCapturePermissionPrompter.presentAlert(openSettingsOnConfirm: true)
            return
        }

        let capability = ScreenshotFlowCapabilityAdapter(kernel: kernel)
        // 挂起池是发送器级全局数组：抓取 / 拖选 / 编码都是异步窗口，期间用户可能
        // 切换会话。必须在流程启动时捕获会话身份，写回前比对，否则 A 发起的截图
        // 会落入 B 的待发送池并随 B 的消息发出（#422，与文件选择路径 #161 同源）。
        let conversationID = capability.selectedConversationID

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
        ) { cropped in
            guard let cropped else { return }
            Task { @MainActor in
                await insert(
                    capability: capability,
                    image: cropped,
                    conversationID: conversationID
                )
            }
        }
    }

    // MARK: - 私有

    /// 将裁剪结果编码为图片附件，加入发送器挂起池供输入框预览。
    ///
    /// 缩放 / JPEG / Base64 是 CPU 与分配密集 work，放到后台 worker 执行，
    /// 完成后再回到主 actor 发布附件（见 issue #1265）。
    /// 写回前比对启动时捕获的 `conversationID` 与当前选中会话，不一致即丢弃（#422）。
    /// 可见性放宽到 internal 仅为便于单元测试覆盖「编码 → 会话校验 → 挂起池」这条链路。
    internal static func insert(
        capability: any ScreenshotFlowCapability,
        image: CGImage,
        conversationID: UUID?
    ) async {
        do {
            let attachment = try await Task.detached(priority: .userInitiated) {
                try ScreenshotFileWriter.makeAttachment(image)
            }.value
            // 编码完成后会话可能已切换：旧截图不得落入新会话的挂起池（#422）。
            guard capability.selectedConversationID == conversationID else {
                logger.info("截图会话已切换，丢弃过期截图")
                return
            }
            capability.addImageAttachment(attachment)
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
