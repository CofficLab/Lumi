import LumiCoreKit
import SwiftUI

public enum MessageRendererPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "CoreMessageRenderer",
        displayName: String(localized: "核心消息渲染器", bundle: .module),
        description: String(localized: "提供内置消息类型的渲染支持", bundle: .module),
        order: 10
    )

    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .general
    public static let iconName = "paintbrush.fill"

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        [
            LumiMessageRendererItem(
                id: "core-error-message",
                order: 300,
                canRender: { $0.role == .error || $0.isError },
                render: { message, showRawMessage in
                    CoreMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-tool-message",
                order: 250,
                canRender: { $0.role == .tool },
                render: { message, showRawMessage in
                    CoreMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-user-message",
                order: 200,
                canRender: { $0.role == .user },
                render: { message, showRawMessage in
                    CoreMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-assistant-message",
                order: 190,
                canRender: { $0.role == .assistant },
                render: { message, showRawMessage in
                    CoreMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-system-message",
                order: 160,
                canRender: { $0.role == .system },
                render: { message, showRawMessage in
                    CoreMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-default-markdown",
                order: 0,
                canRender: { !$0.content.isEmpty },
                render: { message, showRawMessage in
                    CoreMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
        ]
    }
}
