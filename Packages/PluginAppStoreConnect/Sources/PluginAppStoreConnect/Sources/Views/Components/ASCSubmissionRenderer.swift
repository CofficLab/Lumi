import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// App Store Connect 提交审核时间线消息的渲染器。
///
/// order 320 高于 `core-error-message`(300) 与 `core-default-markdown`，
/// 确保提交审核卡片不会被通用渲染器接管。
enum ASCSubmissionRenderer {
    /// 渲染器顺序。数值越大优先级越高。
    static let order = 320

    /// 构造渲染器条目。
    @MainActor
    static func item() -> MessageRendererItem {
        MessageRendererItem(
            id: ASCSubmissionTimeline.rendererID,
            order: order,
            canRender: { message in
                MessageTimelineEvent.isAppStoreSubmission(message)
            },
            render: { message, _ in
                AnyView(ASCSubmissionMessageView(message: message))
            }
        )
    }
}
