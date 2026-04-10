import MagicKit
import SwiftData
import SwiftUI

/// 待发送消息队列视图
/// 显示在输入框上方，展示等待发送的消息列表（不包括正在发送的消息）
struct PendingMessagesView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📋"
    /// 是否输出详细日志
    nonisolated static let verbose = true

    @EnvironmentObject var messageQueueVM: MessageQueueVM
    @EnvironmentObject var conversationVM: ConversationVM

    /// 数据上下文
    @Environment(\.modelContext) private var modelContext

    /// 缓存的会话标题
    @State private var cachedConversationTitle: String?

    var body: some View {
        guard let selectedConversationId = conversationVM.selectedConversationId else { return AnyView(EmptyView()) }
        let pendingMessages = messageQueueVM.pendingMessages(for: selectedConversationId)
        let waitingMessages = pendingMessages

        if !waitingMessages.isEmpty {
            return AnyView(VStack(alignment: .leading, spacing: 6) {
                // 顶部：会话标题
                HStack(spacing: 6) {
                    Image(systemName: "message")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)

                    Text(cachedConversationTitle ?? String(localized: "Current Conversation", table: "AgentInput"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()
                }
                .padding(.bottom, 2)

                Divider()
                    .padding(.bottom, 2)

                // 队列标题
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)

                    Text(String(localized: "Waiting to Send", table: "AgentInput"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)

                    Text("(\(waitingMessages.count))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                // 消息列表
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(waitingMessages, id: \.id) { message in
                            PendingMessageRow(
                                message: message,
                                onRemove: {
                                    messageQueueVM.removeMessage(id: message.id)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(waitingMessages.count) * 36, 120))
            }
            .padding(10)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .onAppear(perform: updateConversationTitle)
            .onChange(of: conversationVM.selectedConversationId, updateConversationTitle)
            )
        }
        return AnyView(EmptyView())
    }

    // MARK: - Event Handler

    private func updateConversationTitle() {
        guard let conversationId = conversationVM.selectedConversationId else {
            cachedConversationTitle = nil
            return
        }

        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate<Conversation> { $0.id == conversationId }
        )

        do {
            cachedConversationTitle = try modelContext.fetch(descriptor).first?.title
        } catch {
            if Self.verbose {
                AgentInputPlugin.logger.error("\(Self.t)❌ 获取会话标题失败：\(error.localizedDescription)")
            }
        }
    }
}

/// 单条待发送消息行
struct PendingMessageRow: View {
    let message: ChatMessage
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            // 等待中图标
            Image(systemName: "hourglass")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.6))

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

            // 移除按钮
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(String(localized: "Remove Message", table: "AgentInput"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.02))
        )
    }
}

// MARK: - Preview
