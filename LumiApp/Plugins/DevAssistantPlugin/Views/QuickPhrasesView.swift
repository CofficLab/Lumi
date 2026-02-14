import SwiftUI

/// 快捷短语视图 - 显示可点击的快捷短语按钮
struct QuickPhrasesView: View {
    let onPhraseSelected: (String) -> Void

    @State private var phrases: [PromptService.QuickPhrase] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .task {
            // 从 PromptService 获取快捷短语
            phrases = await PromptService.shared.getQuickPhrases()
        }
    }
}

/// 快捷短语按钮
struct QuickPhraseButton: View {
    let phrase: PromptService.QuickPhrase
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

// MARK: - Preview

#Preview("Quick Phrases") {
    QuickPhrasesView { phrase in
        print("Selected: \(phrase)")
    }
    .frame(width: 600)
    .background(Color(nsColor: .windowBackgroundColor))
}
