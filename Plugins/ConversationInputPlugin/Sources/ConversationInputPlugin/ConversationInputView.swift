import LumiUI
import SwiftUI

/// 输入框视图（仅 UI 展示）
struct ConversationInputView: View {
    @LumiTheme private var theme
    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 0) {
            AppDivider()
            HStack(alignment: .bottom, spacing: 8) {
                Button {
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
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.textTertiary.opacity(0.3), lineWidth: 1)
                )

                Button {
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
    }
}