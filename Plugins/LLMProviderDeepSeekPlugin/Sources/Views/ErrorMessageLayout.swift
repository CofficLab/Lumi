import LumiKernel
import LumiUI
import SwiftUI

// 泛型 View 不能持有 static 存储属性，格式化器放到非泛型枚举里。
private enum ErrorMessageTimestampFormat {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

/// DeepSeek 错误消息外壳：与 core-user-message / core-assistant-message 等
/// 核心渲染器保持一致的 header（头像 + 身份行 + 复制 + 时间戳，含 hover 动效）
/// + 错误正文两段式布局。
struct ErrorMessageLayout<Content: View>: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference

    let message: LumiChatMessage
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @State private var didCopy = false

    private var copyContent: String {
        var sections: [String] = []
        let summary = (message.content.isEmpty ? message.rawErrorDetail ?? "" : message.content)
        if !summary.isEmpty {
            sections.append(summary)
        }
        if let request = message.metadata["llm.transport.request"], !request.isEmpty {
            sections.append("--- Request ---\n\(request)")
        }
        if let response = message.metadata["llm.transport.response"], !response.isEmpty {
            sections.append("--- Response ---\n\(response)")
        }
        return sections.joined(separator: "\n\n")
    }

    private var headerBackgroundColor: Color {
        isHovered
            ? theme.textSecondary.opacity(0.14)
            : theme.textSecondary.opacity(0.08)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    ChatAvatarView(kind: .error)

                    AppIdentityRow(
                        title: LumiPluginLocalization.string("Error", bundle: .module),
                        metadata: [
                            message.providerID ?? DeepSeekOpenAIProvider.info.id,
                            message.modelName ?? "",
                        ]
                    )
                }

                Spacer()

                HStack(alignment: .center, spacing: 12) {
                    CopyMessageButton(content: copyContent, showFeedback: $didCopy)

                    AppIdentityRow(
                        title: ErrorMessageTimestampFormat.formatter.string(from: message.createdAt),
                        titleColor: theme.textSecondary
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .appSurface(
                style: .custom(headerBackgroundColor),
                cornerRadius: 8,
                borderColor: theme.divider.opacity(isHovered ? 1.0 : 0.65)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                    isHovered = hovering
                }
            }

            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    theme.error.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.error.opacity(0.16), lineWidth: 1)
                )
        }
        // 与普通消息流一致：占满整行宽度，而不是居中显示一条窄错误卡片。
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
