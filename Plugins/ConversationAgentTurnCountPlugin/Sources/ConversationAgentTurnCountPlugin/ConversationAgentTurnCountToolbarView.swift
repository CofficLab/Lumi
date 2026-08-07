import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前对话正在运行的子 Agent Turn 数量。
@MainActor
struct ConversationAgentTurnCountToolbarView: View {
    @LumiTheme private var theme
    // agentTurnManager 的实现 AgentTurnRunner 不是 ObservableObject（其变更经
    // NotificationCenter 的 .lumiTurnStarted/.lumiTurnFinished 广播），故用
    // refreshID token + .onReceive 做「事件驱动半窄播」；conversations 用来读
    // selectedConversationID，用 box 精确订阅。不挂在 kernel 全局总线上。
    let kernel: LumiKernel
    @StateObject private var conversationsBox = ObservableConversationsBox()
    @State private var refreshID = UUID()
    @State private var isPopoverPresented = false

    private var selectedConversationID: UUID? {
        conversationsBox.service?.selectedConversationID
    }

    private var activeCount: Int {
        _ = refreshID
        guard let selectedConversationID,
              let agentTurnManager = kernel.agentTurnManager else {
            return 0
        }
        return agentTurnManager.activeChildTurnCount(for: selectedConversationID)
    }

    var body: some View {
        let count = activeCount

        Group {
            if count > 0 {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.wave.2")
                            .font(.system(size: 11, weight: .medium))
                        Text("\(count)")
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.surface.opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                    AgentTurnCountPopoverContent(count: count)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiTurnStarted)) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiTurnFinished)) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiConversationsDidChange)) { _ in
            refreshID = UUID()
        }
        .onAppear {
            refreshID = UUID()
        }
        .task {
            conversationsBox.bind(kernel.conversations)
        }
    }
}

// MARK: - Popover Content

private struct AgentTurnCountPopoverContent: View {
    @LumiTheme private var theme
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Text("Sub-Agent Turns")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Divider()

            Text("当前有 **\(count)** 个子 Agent Turn 正在并行运行。")
                .font(.caption)
                .foregroundColor(theme.textSecondary)

            Text("当主 Agent 将任务委派给子 Agent 执行时，每个子 Agent 的独立运行轮次都会计入此数字。数字归零表示所有子任务已完成。")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(12)
        .frame(width: 260)
        .background(theme.background)
    }
}
