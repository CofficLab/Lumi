import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 输入框视图（仅 UI 展示）
struct ConversationInputView: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-input.view")
    nonisolated static let verbose = true

    @LumiTheme private var theme
    @State private var text: String = ""

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
                        .onSubmit {
                            if Self.verbose {
                                Self.logger.info("\(Self.t)回车提交 ➡️ text.len=\(text.count)")
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
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if Self.verbose {
                        Self.logger.info("\(Self.t)点击 ➡️ 发送按钮（占位）➡️ text.len=\(trimmed.count), will be wired to kernel.messageSend in a follow-up")
                    }
                    // 发送按钮（占位）
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(text.isEmpty ? theme.textTertiary : theme.primary)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty)
                .help("Send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(theme.background)
        .onAppear {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(Self.onAppear)ConversationInputView")
            }
        }
        .onDisappear {
            if Self.verbose {
                Self.logger.info("\(Self.t)onDisappear ➡️ ConversationInputView")
            }
        }
    }
}
