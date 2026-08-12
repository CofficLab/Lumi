import LumiKernel
import LumiUI
import SwiftUI

/// V1 中一个完整的 AgentTurn。
///
/// List 只负责排列多个本视图；用户消息、Status、工具过程、流式消息和最终结果
/// 都在这里完成组合与阶段切换。pending Turn 使用用户消息 ID，真实 Turn 使用
/// turnID，确保多个历史/子 Turn 在列表中始终拥有唯一身份。
struct AgentTurnView: View {
    let kernel: LumiKernel
    let item: AgentTurnPresentationItem
    let lastAgentTurnID: UUID?
    let verbosity: LumiResponseVerbosity

    @StateObject private var viewModel: AgentTurnViewModel
    @State private var isProcessExpanded = false

    init(
        kernel: LumiKernel,
        item: AgentTurnPresentationItem,
        lastAgentTurnID: UUID?,
        verbosity: LumiResponseVerbosity
    ) {
        self.kernel = kernel
        self.item = item
        self.lastAgentTurnID = lastAgentTurnID
        self.verbosity = verbosity
        _viewModel = StateObject(wrappedValue: AgentTurnViewModel(kernel: kernel, item: item))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.projection.userMessages) { message in
                messageRow(message)
            }

            if !viewModel.projection.processMessages.isEmpty {
                processDisclosure
            }

            if let lastMessage = viewModel.projection.lastMessage {
                messageRow(lastMessage)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if isConversationTail, let activityMessage = viewModel.projection.activityMessage {
                messageRow(activityMessage)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .task { await viewModel.activate() }
        .onChange(of: item) { _, newItem in
            Task { await viewModel.update(item: newItem) }
        }
        .animation(.easeOut(duration: 0.18), value: visibleMessageIDs)
    }

    private var processDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.isShowingProcess {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    processDisclosureButton(now: context.date)
                }
            } else {
                processDisclosureButton(now: .now)
            }

            if isProcessExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.projection.processMessages) { message in
                        messageRow(message)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func processDisclosureButton(now: Date) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isProcessExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isProcessExpanded ? "chevron.down" : "chevron.right")
                Text(AgentTurnViewModel.processDisclosureTitle(
                    item: item,
                    userMessages: viewModel.projection.userMessages,
                    processCount: viewModel.projection.processMessages.count,
                    now: now
                ))
            }
            .font(.appCaption)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// List 只提供尾部身份；消息与活动状态仍由本 Turn 自行获取。
    private var isConversationTail: Bool {
        item.id == lastAgentTurnID
    }

    private var visibleMessageIDs: [UUID] {
        viewModel.projection.userMessages.map(\.id)
            + (isProcessExpanded ? viewModel.projection.processMessages.map(\.id) : [])
            + (viewModel.projection.lastMessage.map { [$0.id] } ?? [])
            + (isConversationTail ? viewModel.projection.activityMessage.map { [$0.id] } ?? [] : [])
    }

    private func messageRow(_ message: LumiChatMessage) -> some View {
        MessageRowView(
            kernel: kernel,
            message: message,
            verbosity: verbosity
        )
        .id(message.id)
    }
}
