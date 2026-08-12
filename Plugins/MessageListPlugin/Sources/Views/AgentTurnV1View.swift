import LumiKernel
import SwiftUI

/// V1 中一个稳定的 AgentTurn 容器。
///
/// 活跃时显示过程时间线；同一个 turnID 进入终态后，过程以收缩/淡出动画替换为
/// 最终结果。历史终态 Turn 首次创建时直接处于结果态，因此不会重播动画。
struct AgentTurnV1View: View {
    let kernel: LumiKernel
    let item: AgentTurnSummaryItem
    let streamingMessage: LumiChatMessage?
    let verbosity: LumiResponseVerbosity

    private var liveMessages: [LumiChatMessage] {
        guard let streamingMessage else { return item.processMessages }
        return item.processMessages + [streamingMessage]
    }

    var body: some View {
        Group {
            if item.isShowingProcess {
                processTimeline
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                    )
            } else {
                MessageRowView(
                    kernel: kernel,
                    message: item.message,
                    verbosity: verbosity
                )
                .transition(
                    .opacity.combined(with: .move(edge: .bottom))
                )
            }
        }
        .animation(.easeInOut(duration: 0.28), value: item.isShowingProcess)
    }

    @ViewBuilder
    private var processTimeline: some View {
        if liveMessages.isEmpty {
            MessageRowView(
                kernel: kernel,
                message: item.message,
                verbosity: verbosity
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(liveMessages) { message in
                    MessageRowView(
                        kernel: kernel,
                        message: message,
                        verbosity: verbosity
                    )
                    .id(message.id)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: liveMessages.map(\.id))
        }
    }
}
