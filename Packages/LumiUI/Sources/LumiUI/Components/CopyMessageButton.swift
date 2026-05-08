import AppKit
import SwiftUI

public struct CopyMessageButton: View {
    @LumiTheme private var theme

    let content: String
    @Binding var showFeedback: Bool

    @State private var isHovered = false

    public init(content: String, showFeedback: Binding<Bool>) {
        self.content = content
        self._showFeedback = showFeedback
    }

    public var body: some View {
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
            theme.success
        } else {
            theme.textSecondary.opacity(0.8)
        }
    }

    private var backgroundColor: Color {
        if showFeedback {
            theme.success.opacity(0.1)
        } else {
            isHovered ? theme.textSecondary.opacity(0.08) : theme.textSecondary.opacity(0.05)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)

        showFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showFeedback = false
        }
    }
}
