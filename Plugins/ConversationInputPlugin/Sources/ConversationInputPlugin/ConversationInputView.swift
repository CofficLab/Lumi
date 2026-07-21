import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 输入框视图（仅 UI 展示）
struct ConversationInputView: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-input.view")
    nonisolated static let verbose = true

    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel
    @State private var text: String = ""

    /// 当前是否在向内核发送中；用于禁用输入控件。
    private var isSending: Bool {
        kernel.messageSend?.isSending ?? false
    }

    /// 当前是否没有任何发送能力可用（kernel 还没注册 messageSend）。
    private var hasSendCapability: Bool {
        kernel.messageSend != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            AppDivider()
            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)点击 ➡️ 附件按钮（占位）")
                    }
                    // 附件按钮（占位）
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("Attach file")

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Send a message...")
                            .foregroundColor(theme.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $text)
                        .font(.body)
                        .foregroundColor(theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 36, maxHeight: 160)
                        .disabled(isSending)
                        .onSubmit {
                            if canSend {
                                send()
                            }
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.textTertiary.opacity(0.3), lineWidth: 1)
                )

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(canSend ? theme.primary : theme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help(hasSendCapability ? "Send" : "Message send is not available")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(theme.background)
        .onAppear {
            if Self.verbose {
                Self.logger.info("\(Self.t)ConversationInputView (hasSendCapability=\(hasSendCapability))")
            }
        }
        .onDisappear {
            if Self.verbose {
                Self.logger.info("\(Self.t)onDisappear ➡️ ConversationInputView")
            }
        }
    }

    private var canSend: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isSending && hasSendCapability
    }

    /// 触发一次发送:trim → kernel.messageSend?.sendMessage → 清空输入。
    ///
    /// 由协议契约:`sendMessage` 在没有选中会话时会抛
    /// `LumiKernelError.noActiveConversation`;这里用 `try?` 吞掉,只打
    /// `error` 日志,UI 不弹 alert(后续接 Chat 状态后再补)。
    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(Self.t)send ➡️ 空白输入, no-op")
            }
            return
        }
        guard let messageSend = kernel.messageSend else {
            Self.logger.error("\(Self.t)send ➡️ kernel.messageSend 为 nil, 无法发送")
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)send ➡️ text.len=\(trimmed.count), conversationID=nil (由实现选 selected)")
        }
        let payload = trimmed
        Task { @MainActor in
            do {
                try await messageSend.sendMessage(payload, conversationID: nil)
                if Self.verbose {
                    Self.logger.info("\(Self.t)send ➡️ sendMessage 返回成功, 清空输入")
                }
                text = ""
            } catch {
                Self.logger.error("\(Self.t)send ➡️ sendMessage 抛出: \(error.localizedDescription)")
            }
        }
    }
}
