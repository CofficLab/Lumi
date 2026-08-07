import LumiKernel
import LumiUI
import SwiftUI

struct ConversationReasoningActionBarButton: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 推理强度的能力判定与持久化同时依赖「当前对话的 provider/model」（随会话切换变化，
    // 由 .onLumiSelectedConversationDidChange 事件驱动）与「provider 注册表的能力元数据」
    // （由 providerBox 精确订阅）。不挂 kernel 全局总线。
    @StateObject private var providerBox = ObservableLLMProviderBox()

    @State private var isPopoverPresented = false
    @State private var localEffort: LumiReasoningEffort = .defaultEffort
    @State private var selectedConversationID: UUID?

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var llmProvider: (any LLMProviderManaging)? {
        providerBox.service
    }

    private var selectedProviderID: String? {
        if let conversationProviderID = selectedConversationID.flatMap({ conversations?.providerID(for: $0) }) {
            return conversationProviderID
        }
        return llmProvider?.selectedProviderID
    }

    private var selectedModel: String? {
        if let selectedConversationID,
           conversations?.providerID(for: selectedConversationID) != nil,
           let conversationModel = conversations?.modelName(for: selectedConversationID) {
            return conversationModel
        }
        return llmProvider?.selectedModel
    }

    private var selectedModelCapabilities: LumiModelCapabilities? {
        guard let selectedProviderID,
              let provider = llmProvider?.llmProvider(id: selectedProviderID) else {
            return nil
        }
        let info = type(of: provider).info
        let model = selectedModel ?? info.defaultModel
        return info.modelCapabilities[model]
    }

    private var supportsReasoningEffort: Bool {
        selectedModelCapabilities?.supportsReasoningEffort == true
    }

    private var persistedEffort: LumiReasoningEffort {
        conversations?.reasoningEffort(for: selectedConversationID) ?? .defaultEffort
    }

    var body: some View {
        Group {
            if supportsReasoningEffort {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.system(size: 13, weight: .medium))
                        Text(localEffort.levelCode)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.textTertiary)
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.textTertiary.opacity(0.2))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Reasoning: \(localEffort.displayName)")
                .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
                    ConversationReasoningPopover(selectedEffort: localEffort) { effort in
                        select(effort)
                        isPopoverPresented = false
                    }
                }
                .accessibilityLabel("Select Reasoning Effort")
            }
        }
        .onAppear(perform: syncFromConversation)
        .onChange(of: selectedConversationID) { _, _ in
            syncFromConversation()
        }
        .onChange(of: supportsReasoningEffort) { _, supports in
            if supports {
                syncFromConversation()
            } else {
                isPopoverPresented = false
            }
        }
        .task {
            selectedConversationID = kernel.conversations?.selectedConversationID
            providerBox.bind(kernel.resolveService((any LLMProviderManaging).self))
        }
        .onLumiSelectedConversationDidChange { newID in
            selectedConversationID = newID
        }
    }

    private func select(_ effort: LumiReasoningEffort) {
        localEffort = effort
        conversations?.setReasoningEffort(effort, for: selectedConversationID)
    }

    private func syncFromConversation() {
        localEffort = persistedEffort
    }
}

private struct ConversationReasoningPopover: View {
    let selectedEffort: LumiReasoningEffort
    let onSelect: (LumiReasoningEffort) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reasoning Effort")
                .font(.system(size: 12, weight: .semibold))

            ForEach(LumiReasoningEffort.allCases) { effort in
                Button {
                    onSelect(effort)
                } label: {
                    ConversationReasoningRow(effort: effort, isSelected: effort == selectedEffort)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}

private struct ConversationReasoningRow: View {
    let effort: LumiReasoningEffort
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: effort.iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(effort.levelCode)
                        .font(.system(size: 12, weight: .semibold))
                    Text(effort.displayName)
                        .font(.system(size: 11))
                }
                .foregroundColor(.primary)

                Text(effort.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
