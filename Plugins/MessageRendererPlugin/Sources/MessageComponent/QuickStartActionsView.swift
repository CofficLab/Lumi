import LumiUI
import Foundation
import SwiftUI

public struct QuickStartActionsView: View {
    enum SendStrategy {
        case createConversationAndSend
        case sendInCurrentConversation
    }

    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let sendStrategy: SendStrategy

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "下一步操作", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)

            ForEach(recommendedPrompts, id: \.self) { prompt in
                AppButton(
                    LocalizedStringKey(prompt),
                    style: .tonal,
                    size: .small,
                    fillsWidth: false
                ) {
                    handleTap(prompt: prompt)
                }
            }
        }
    }

    private var recommendedPrompts: [String] {
        switch MessageRendererRuntime.languagePreference {
        case .chinese:
            return [
                "帮我解释这段错误日志",
                "把这个需求拆成 3 个可执行小任务",
                "给我一个今天就能开始执行的学习计划"
            ]
        case .english:
            return [
                "Explain this error log",
                "Break this requirement into three actionable tasks",
                "Give me a troubleshooting checklist"
            ]
        }
    }

    private func handleTap(prompt: String) {
        MessageRendererRuntime.enqueueText(prompt)
    }
}

#Preview {
    QuickStartActionsView(sendStrategy: .sendInCurrentConversation)
}
