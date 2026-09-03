import ProviderAgentLoop
import SwiftUI

/// Agent Turn 运行状态工具栏视图
struct AgentTurnStatusToolbarView: View {
    let agentLoop: any AgentLoopProviding
    @ObservedObject var state: AgentTurnStatusToolbarState

    @State private var isRunning: Bool = false
    @State private var pulseAnimation: Bool = false

    var body: some View {
        Group {
            if isRunning {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseAnimation ? 1.3 : 0.8)
                        .opacity(pulseAnimation ? 0.6 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                    Image(systemName: "person.2.wave.2")
                        .font(.system(size: 10, weight: .medium))
                    Text(LumiPluginLocalization.string("Running", bundle: .module))
                        .font(.system(size: 10, weight: .medium))
                        .contentTransition(.opacity)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Color.orange.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .onAppear { pulseAnimation = true }
                .onDisappear { pulseAnimation = false }
            }
        }
        .task(id: "\(state.selectedConversationID?.uuidString ?? "nil")-\(state.revision)") {
            await Task.yield()
            guard !Task.isCancelled else { return }
            updateRunningState()
        }
    }

    private func updateRunningState() {
        guard let conversationID = state.selectedConversationID else {
            isRunning = false
            return
        }
        isRunning = agentLoop.isRunning(for: conversationID)
    }
}
