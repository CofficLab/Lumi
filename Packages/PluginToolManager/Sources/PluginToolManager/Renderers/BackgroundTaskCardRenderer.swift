import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 后台任务通知卡片的消息渲染器。
///
/// 渲染器只负责「把通知消息画成卡片」以及把「停止」按钮点击转交给
/// `BackgroundTaskRegistry`；它不关心这条消息是怎么来的。
enum BackgroundTaskCardRenderer {
    /// 构造渲染器条目。
    ///
    /// - Parameter order: 渲染优先级，数值越大越优先。
    @MainActor
    static func item(
        order: Int,
        registryProvider: @escaping @MainActor @Sendable () -> BackgroundTaskRegistry?
    ) -> MessageRendererItem {
        MessageRendererItem(
            id: BackgroundTaskNotification.rendererID,
            order: order,
            canRender: { message in
                isBackgroundNotification(message)
            },
            render: { message, _ in
                AnyView(view(for: message, registryProvider: registryProvider))
            }
        )
    }

    /// 判断消息是否是后台任务通知。
    static func isBackgroundNotification(_ message: Message) -> Bool {
        message.metadata[BackgroundTaskNotification.metadataKey] == "1"
    }

    /// 按消息构造对应视图。
    ///
    /// 载荷缺失时回退到纯文本摘要，避免渲染空白。
    @MainActor
    @ViewBuilder
    private static func view(
        for message: Message,
        registryProvider: @escaping @MainActor @Sendable () -> BackgroundTaskRegistry?
    ) -> some View {
        if let payload = decodePayload(from: message.metadata) {
            BackgroundTaskCardView(
                taskID: payload.taskID,
                status: payload.status,
                exitCode: payload.exitCode,
                outputPath: payload.outputPath,
                content: message.content,
                registry: registryProvider()
            )
        } else {
            BackgroundTaskCardFallbackView(message: message)
        }
    }

    /// 从 metadata 解析卡片载荷。
    static func decodePayload(from metadata: [String: String]) -> Payload? {
        guard let taskID = metadata[BackgroundTaskNotification.taskIDKey],
              !taskID.isEmpty,
              let statusRaw = metadata[BackgroundTaskNotification.statusKey],
              let status = BackgroundTaskStatus(rawValue: statusRaw)
        else {
            return nil
        }
        let exitCodeText = metadata[BackgroundTaskNotification.exitCodeKey] ?? ""
        let exitCode: Int32? = exitCodeText.isEmpty ? nil : Int32(exitCodeText)
        return Payload(
            taskID: taskID,
            status: status,
            exitCode: exitCode,
            outputPath: metadata[BackgroundTaskNotification.outputPathKey] ?? ""
        )
    }

    /// 卡片载荷。
    struct Payload {
        let taskID: String
        let status: BackgroundTaskStatus
        let exitCode: Int32?
        let outputPath: String
    }
}

/// 载荷缺失时的回退视图。
struct BackgroundTaskCardFallbackView: View {
    let message: Message

    var body: some View {
        Text(message.content)
            .font(.callout)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}
