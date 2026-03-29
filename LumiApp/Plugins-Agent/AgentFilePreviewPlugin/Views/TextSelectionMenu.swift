import MagicKit
import SwiftUI

/// 文本选中小型操作菜单（复制、剪切）
struct TextSelectionMenu: View {
    /// 当前选中的文本
    let selectedText: String

    /// 是否可编辑（影响是否显示剪切按钮）
    let isEditable: Bool

    /// 剪切操作回调
    let onCut: () -> Void

    /// 复制操作回调
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 复制按钮
            menuButton(
                icon: "doc.on.doc",
                title: String(localized: "Copy", table: "AgentFilePreview"),
                action: onCopy
            )

            // 分割线
            if isEditable {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 16)

                // 剪切按钮
                menuButton(
                    icon: "scissors",
                    title: String(localized: "Cut", table: "AgentFilePreview"),
                    action: onCut
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }

    private func menuButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(AppUI.Color.semantic.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("可编辑") {
    ZStack {
        Color.gray.opacity(0.3)
        TextSelectionMenu(
            selectedText: "Hello",
            isEditable: true,
            onCut: {},
            onCopy: {}
        )
    }
    .frame(width: 300, height: 200)
}

#Preview("只读") {
    ZStack {
        Color.gray.opacity(0.3)
        TextSelectionMenu(
            selectedText: "Hello",
            isEditable: false,
            onCut: {},
            onCopy: {}
        )
    }
    .frame(width: 300, height: 200)
}
