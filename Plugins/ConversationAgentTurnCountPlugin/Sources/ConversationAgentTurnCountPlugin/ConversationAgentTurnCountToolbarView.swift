import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前对话正在运行的子 Agent Turn 数量。
@MainActor
struct ConversationAgentTurnCountToolbarView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel
    @State private var refreshID = UUID()

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
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
                .help("Running sub-agent turns: \(count)")
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
    }
}
