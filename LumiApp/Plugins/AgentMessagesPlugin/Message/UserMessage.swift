import MagicKit
import SwiftUI

// MARK: - User Message
//
/// 负责完整渲染一条用户消息（包含头部与正文）
struct UserMessage: View {
    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @EnvironmentObject private var inputQueueVM: InputQueueVM

    /// 当前 macOS 登录用户名称
    private var currentUserName: String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? NSUserName() : fullName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            VStack(alignment: .leading, spacing: 8) {
                if !message.images.isEmpty {
                    UserMessageImageGrid(images: message.images)
                }

                if !message.content.isEmpty {
                    PlainTextMessageContentView(
                        content: message.content,
                        monospaced: false
                    )
                }
            }
            .messageBubbleStyle(role: message.role, isError: message.isError)
        }
    }

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            HStack(alignment: .center, spacing: 4) {
                Text(currentUserName)
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                Button {
                    resend()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                        Text("重发")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .help("重新发送该消息")

                Text(formatTimestamp(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }

    private func resend() {
        inputQueueVM.enqueueText(message.content)
    }
}

private struct UserMessageImageGrid: View {
    let images: [ImageAttachment]
    @State private var previewingImage: NSImage?

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 120, maximum: 220), spacing: 8, alignment: .leading),
            ],
            spacing: 8
        ) {
            ForEach(images) { attachment in
                if let nsImage = NSImage(data: attachment.data) {
                    Button {
                        previewingImage = nsImage
                    } label: {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 180, height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("点击预览图片")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { previewingImage != nil },
            set: { isPresented in
                if !isPresented { previewingImage = nil }
            }
        )) {
            if let previewingImage {
                UserMessageImagePreviewSheet(image: previewingImage)
            }
        }
    }
}

private struct UserMessageImagePreviewSheet: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            GeometryReader { geometry in
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .padding(20)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}
