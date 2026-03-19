import SwiftUI

struct QuickStartActionsView: View {
    enum SendStrategy {
        case createConversationAndSend
        case sendInCurrentConversation
    }

    @EnvironmentObject private var app: GlobalVM
    @EnvironmentObject private var agentProvider: AgentVM

    let sendStrategy: SendStrategy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("下一步操作")
                .font(.caption)
                .foregroundStyle(.tertiary)

            ForEach(recommendedPrompts, id: \.self) { prompt in
                Button(prompt) {
                    handleTap(prompt: prompt)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var recommendedPrompts: [String] {
        if app.selectedMode == .app {
            return [
                "我想快速完成一个常见操作，先推荐我该用哪个功能",
                "请给我一个 3 步上手路径，告诉我先点哪里",
                "我现在不知道从哪里开始，给我一个最短操作建议"
            ]
        }

        switch agentProvider.chatMode {
        case .chat:
            if agentProvider.isProjectSelected {
                let projectName = normalizedProjectName
                return [
                    "先帮我总结\(projectName)当前最值得关注的问题",
                    "请用非技术同学也能懂的方式解释这段报错",
                    "把这个需求拆成 3 个可执行小任务"
                ]
            }

            return [
                "帮我解释这段错误日志",
                "把这个需求拆成 3 个可执行小任务",
                "给我一个今天就能开始执行的学习计划"
            ]

        case .build:
            if agentProvider.isProjectSelected {
                let projectName = normalizedProjectName
                return [
                    "先为\(projectName)做一次代码结构扫描并给重构优先级",
                    "请基于当前项目生成一个最小可执行测试计划",
                    "先列出我现在最该修的 3 个潜在风险点"
                ]
            }

            return [
                "帮我为这个项目设计一个测试计划",
                "帮我梳理当前项目的重构优先级",
                "请给我一个可执行的排障清单"
            ]
        }
    }

    private var normalizedProjectName: String {
        let name = agentProvider.currentProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "当前项目" : name
    }

    private func handleTap(prompt: String) {
        switch sendStrategy {
        case .createConversationAndSend:
            Task {
                await agentProvider.createNewConversation()
                await MainActor.run {
                    agentProvider.sendMessage(input: prompt)
                }
            }
        case .sendInCurrentConversation:
            agentProvider.sendMessage(input: prompt)
        }
    }
}

#Preview {
    QuickStartActionsView(sendStrategy: .sendInCurrentConversation)
        .inRootView()
}
