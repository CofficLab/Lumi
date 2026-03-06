import MagicKit
import SwiftUI

/// 待发送消息队列视图
/// 显示在输入框上方，展示等待发送的消息列表
struct PendingMessagesView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📋"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    var body: some View {
        let messageSenderVM = agentProvider.messageSenderViewModel
        let pendingMessages = messageSenderVM.pendingMessages
        let currentProcessingIndex = messageSenderVM.currentProcessingIndex
        let isSending = messageSenderVM.isSending

        if !pendingMessages.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                // 队列标题
                HStack(spacing: 6) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Text(isSending ? "正在发送..." : "等待发送")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("(\(pendingMessages.count))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))

                    Spacer()

                    // 清空队列按钮
                    Button(action: {
                        messageSenderVM.clearQueue()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("清空队列")
                }

                // 消息列表
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(pendingMessages.enumerated()), id: \.element.id) { index, message in
                            PendingMessageRow(
                                message: message,
                                index: index,
                                isProcessing: index == currentProcessingIndex,
                                onRemove: index != currentProcessingIndex ? {
                                    messageSenderVM.removeMessage(at: index)
                                } : nil
                            )
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(pendingMessages.count) * 36, 120))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

/// 单条待发送消息行
struct PendingMessageRow: View {
    let message: ChatMessage
    let index: Int
    let isProcessing: Bool
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            // 状态图标
            if isProcessing {
                // 正在发送
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
            } else {
                // 等待中
                Image(systemName: "hourglass")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            // 消息内容预览
            Text(message.content.prefix(80))
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            // 图片附件标识
            if !message.images.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "photo")
                        .font(.system(size: 9))
                    Text("\(message.images.count)")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary.opacity(0.6))
            }

            Spacer()

            // 移除按钮（非发送中消息才显示）
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("移除此消息")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isProcessing ? Color.accentColor.opacity(0.15) : Color.black.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isProcessing ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Pending Messages") {
    VStack {
        PendingMessagesView()
        Spacer()
    }
    .frame(width: 600, height: 400)
    .padding()
    .inRootView()
}