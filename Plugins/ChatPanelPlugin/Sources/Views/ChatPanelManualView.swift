import LumiUI
import SwiftUI

// MARK: - Manual View

/// 对话面板使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节与编号步骤,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct ChatPanelManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Chat"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the Chat panel, the core workspace of Lumi where you work with the AI."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Click the Chat icon in the activity bar to open the chat workspace.")),
                .init(L("Type your question in the input field and press Return to send it.")),
                .init(L("The AI replies in the conversation; you can also ask it to perform tasks for you.")),
            ])

            ManualSectionHeader(number: 3, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Configure an AI provider in Settings before using the chat.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        ChatPanelManualView()
            .padding(22)
    }
    .frame(width: 560, height: 700)
}
