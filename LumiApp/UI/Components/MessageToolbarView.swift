import SwiftUI

// MARK: - Copy Message Button

/// 复制消息内容按钮
struct CopyMessageButton: View {
    let content: String
    @Binding var showFeedback: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .medium))
                if showFeedback {
                    Text("已复制")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(buttonColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .help("复制消息内容")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var iconName: String {
        showFeedback ? "checkmark" : "doc.on.doc"
    }
    
    private var buttonColor: Color {
        if showFeedback {
            return .green
        }
        return DesignTokens.Color.semantic.textSecondary.opacity(0.8)
    }
    
    private var backgroundColor: Color {
        if showFeedback {
            return Color.green.opacity(0.1)
        }
        return isHovered ? DesignTokens.Color.semantic.textSecondary.opacity(0.08) : DesignTokens.Color.semantic.textSecondary.opacity(0.05)
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // 显示反馈
        showFeedback = true
        
        // 2 秒后隐藏反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showFeedback = false
        }
    }
}

// MARK: - Preview

