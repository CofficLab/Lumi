import SwiftUI

/// 快捷短语视图 - 显示可点击的快捷短语按钮
struct QuickPhrasesView: View {
    let onPhraseSelected: (String) -> Void

    // 项目信息（从 ViewModel 传入）
    @Binding var projectName: String
    @Binding var projectPath: String
    @Binding var isProjectSelected: Bool

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
            await refreshPhrases()
        }
        .onChange(of: isProjectSelected) { _, _ in
            Task { await refreshPhrases() }
        }
        .onChange(of: projectName) { _, _ in
            Task { await refreshPhrases() }
        }
    }

    private func refreshPhrases() async {
        // 根据项目状态传递不同的参数
        if isProjectSelected {
            phrases = await PromptService.shared.getQuickPhrases(
                projectName: projectName,
                projectPath: projectPath
            )
        } else {
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

#Preview("Quick Phrases - With Project") {
    QuickPhrasesView(
        onPhraseSelected: { print("Selected: \($0)") },
        projectName: .constant("Lumi"),
        projectPath: .constant("/Users/angel/Code/Coffic/Lumi"),
        isProjectSelected: .constant(true)
    )
    .frame(width: 600)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Quick Phrases - No Project") {
    QuickPhrasesView(
        onPhraseSelected: { print("Selected: \($0)") },
        projectName: .constant(""),
        projectPath: .constant(""),
        isProjectSelected: .constant(false)
    )
    .frame(width: 600)
    .background(Color(nsColor: .windowBackgroundColor))
}
