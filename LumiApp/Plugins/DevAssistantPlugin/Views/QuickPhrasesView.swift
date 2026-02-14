import SwiftUI

/// 快捷短语视图 - 显示可点击的快捷短语按钮
struct QuickPhrasesView: View {
    let onPhraseSelected: (String) -> Void

    // 定义快捷短语列表
    private let phrases: [QuickPhrase] = [
        QuickPhrase(
            icon: "checkmark.circle",
            title: "英文 Commit",
            subtitle: "提交英文 commit",
            prompt: "请帮我生成一个英文的 commit message，说明当前代码的改动。请遵循 conventional commits 规范（feat/fix/docs/refactor 等）。"
        ),
        QuickPhrase(
            icon: "checkmark.circle",
            title: "中文 Commit",
            subtitle: "提交中文 commit",
            prompt: "请帮我生成一个中文的 commit message，说明当前代码的改动。请遵循 conventional commits 规范（feat/fix/docs/refactor 等）。"
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷短语")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(phrases) { phrase in
                        QuickPhraseButton(phrase: phrase) {
                            onPhraseSelected(phrase.prompt)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }
}

/// 快捷短语按钮
struct QuickPhraseButton: View {
    let phrase: QuickPhrase
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: phrase.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(phrase.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(phrase.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovering ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// 快捷短语数据模型
struct QuickPhrase: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let prompt: String
}

// MARK: - Preview

#Preview("Quick Phrases") {
    QuickPhrasesView { phrase in
        print("Selected: \(phrase)")
    }
    .frame(width: 600)
    .background(Color(nsColor: .windowBackgroundColor))
}
