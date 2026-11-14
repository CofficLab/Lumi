import Foundation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 错误消息渲染器。
///
/// order 低于各 Provider 自己的错误渲染器（它们取 210–250），
/// 让 Provider 特定错误优先被接管。
enum CoreErrorMessageRenderer {
    /// 构造渲染器条目。
    ///
    /// - Parameters:
    ///   - capability: 消息行可发起的外部操作集合。
    ///   - baseOrder: 渲染优先级基数。
    @MainActor
    static func item(
        capability: any MessageRendererCapability,
        baseOrder: Int
    ) -> MessageRendererItem {
        MessageRendererItem(
            id: "core-error-message",
            order: baseOrder + 290,
            canRender: { message in
                message.role == .error || message.isError
            },
            render: { [capability] message, verbosity in
                let view = AnyView(
                    verbosity == .chatGPT
                        ? AnyView(ChatGPTErrorMessageView(
                            capability: capability,
                            message: message,
                            verbosity: verbosity
                        ))
                        : verbosity == .zcode
                            ? AnyView(ZCodeTimelineMarkerView(message: message))
                            : AnyView(ErrorMessageView(
                                capability: capability,
                                message: message,
                                verbosity: verbosity
                            ))
                )
                return CoreMessageRenderer.attachMenu(
                    to: view,
                    capability: capability,
                    message: message
                )
            }
        )
    }
}
