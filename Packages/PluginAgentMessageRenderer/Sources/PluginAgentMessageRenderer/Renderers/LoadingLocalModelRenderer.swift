import SwiftUI
import LumiCoreKit
import LumiUI

/// 本地模型加载状态渲染器
public struct LoadingLocalModelRenderer: SuperMessageRenderer {
    public static let id = "loading-local-model"
    public static let priority = 190

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        message.content == ChatMessage.loadingLocalModelSystemContentKey
            || message.content == ChatMessage.loadingLocalModelDoneSystemContentKey
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 4) {
                MessageHeaderView {
                    HStack(alignment: .center, spacing: 6) {
                        AvatarView.system
                        AppIdentityRow(
                            title: "System",
                            titleColor: Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
                        )
                    }
                } trailing: {
                    Text(formatTimestamp(message.timestamp))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }

                LoadingLocalModelSystemMessageView(message: message)
                    .messageBubbleStyle(role: message.role, isError: false)
            }
        )
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}
