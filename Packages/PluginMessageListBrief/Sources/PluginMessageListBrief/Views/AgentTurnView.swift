import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// V1 中一个完整的 AgentTurn。
///
/// List 只负责排列多个本视图；用户消息、Status、工具过程、流式消息和最终结果
/// 都在这里完成组合与阶段切换。pending Turn 使用用户消息 ID，真实 Turn 使用
/// turnID，确保多个历史/子 Turn 在列表中始终拥有唯一身份。
struct AgentTurnView: View {
    let services: MessageListServices
    let item: AgentTurnPresentationItem
    let verbosity: ResponseVerbosity
    let isDeveloperModeEnabled: Bool

    @ObservedObject private var viewModel: AgentTurnViewModel
    let onDynamicContentChange: (@MainActor () -> Void)?
    @State private var isProcessExpanded = false

    init(
        services: MessageListServices,
        item: AgentTurnPresentationItem,
        verbosity: ResponseVerbosity,
        isDeveloperModeEnabled: Bool,
        viewModel: AgentTurnViewModel,
        onDynamicContentChange: (@MainActor () -> Void)? = nil
    ) {
        self.services = services
        self.item = item
        self.verbosity = verbosity
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onDynamicContentChange = onDynamicContentChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.projection.userMessages) { message in
                messageRow(message)
            }

            if item.isShowingProcess || !viewModel.projection.processMessages.isEmpty {
                processDisclosure
            }

            if let lastMessage = viewModel.projection.lastMessage {
                messageRow(lastMessage)
            }

            if item.acceptsLiveActivity, let activity = viewModel.projection.activity {
                AgentActivityView(activity: activity)
            }
        }
        .task { await viewModel.activate() }
        .onChange(of: item) { _, newItem in
            Task { await viewModel.update(item: newItem) }
        }
        .onChange(of: viewModel.projection) { _, _ in
            onDynamicContentChange?()
        }
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
                    }
                }
            }
        }
        // Only animate the disclosure container's height. Animating the whole
        // turn by message IDs makes List re-layout every child row at once,
        // which causes the surrounding rows to jump and the Markdown content
        // to flash while the process section is inserted.
        .animation(.easeInOut(duration: 0.2), value: isProcessExpanded)
    }

    private func processDisclosureButton(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    isProcessExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isProcessExpanded ? "chevron.down" : "chevron.right")
                        Text(AgentTurnViewModel.processDisclosureTitle(
                            item: item,
                            userMessages: viewModel.projection.userMessages,
                            processMessages: viewModel.projection.processMessages,
                            now: now
                        ))
                    }
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                if item.isShowingProcess,
                   let turnID = item.record?.id,
                   let toolManager = services.toolManager {
                    AppIconButton(
                        systemImage: "stop.fill",
                        tint: .red,
                        size: .compact
                    ) {
                        toolManager.cancelJobs(forTurnID: turnID)
                    }
                    .help("停止当前回合")
                }
            }

            Divider()
        }
    }

    private func messageRow(_ message: Message) -> some View {
        MessageRowView(
            services: services,
            message: message,
            verbosity: verbosity,
            isDeveloperModeEnabled: isDeveloperModeEnabled
        )
        .id(message.id)
    }
}
