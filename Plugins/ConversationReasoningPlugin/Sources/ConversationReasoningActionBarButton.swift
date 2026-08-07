import LumiKernel
import LumiUI
import SwiftUI

struct ConversationReasoningActionBarButton: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 推理强度的能力判定跟随全局模型选择（与 ModelSelectorPlugin 一致），
    // 持久化按对话维度存储。
    @State private var isPopoverPresented = false
    @State private var localEffort: LumiReasoningEffort = .defaultEffort
    @State private var selectedConversationID: UUID?
    // provider/model 选择变化时 bump 此 token 触发 computed 重算。
    @State private var providerRefreshID = UUID()

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var llmProvider: (any LLMProviderManaging)? {
        _ = providerRefreshID
        return kernel.resolveService((any LLMProviderManaging).self)
    }

    /// 跟随全局模型选择（与 ModelSelectorPlugin 一致）
    private var selectedProviderID: String? {
        llmProvider?.selectedProviderID
    }

    /// 跟随全局模型选择（与 ModelSelectorPlugin 一致）
    private var selectedModel: String? {
        llmProvider?.selectedModel
    }

    private var selectedModelCapabilities: LumiModelCapabilities? {
        guard let selectedProviderID,
              let provider = llmProvider?.llmProvider(id: selectedProviderID) else {
            return nil
        }
        let info = type(of: provider).info
        let model = selectedModel ?? info.defaultModel
        return info.modelInfo(for: model)?.capabilities
    }

    private var supportsThinking: Bool {
        selectedModelCapabilities?.supportsThinking == true
    }

    private var persistedEffort: LumiReasoningEffort {
        conversations?.reasoningEffort(for: selectedConversationID) ?? .defaultEffort
    }

    var body: some View {
        Group {
            if supportsThinking {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.system(size: 11, weight: .medium))
                        Text(localEffort.levelCode)
                            .font(.appCaptionEmphasized)
                        Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                            .font(.appMicroEmphasized)
                            .foregroundColor(theme.textTertiary)
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .fill(theme.appStatusMutedFill)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
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
        .onChange(of: supportsThinking) { _, supports in
            if supports {
                syncFromConversation()
            } else {
                isPopoverPresented = false
            }
        }
        .task {
            selectedConversationID = kernel.conversations?.selectedConversationID
        }
        .onLumiSelectedConversationDidChange { newID in
            selectedConversationID = newID
        }
        .onLumiSelectedRemoteProviderIDDidChange { providerRefreshID = UUID() }
        .onLumiSelectedLocalProviderIDDidChange { providerRefreshID = UUID() }
        .onLumiSelectedModelsDidChange { providerRefreshID = UUID() }
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
                .font(.appCaptionEmphasized)

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
    @LumiTheme private var theme
    let effort: LumiReasoningEffort
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: effort.iconName)
                .font(.appCallout)
                .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(effort.levelCode)
                        .font(.appCaptionEmphasized)
                    Text(effort.displayName)
                        .font(.appMicro)
                }
                .foregroundColor(theme.textPrimary)

                Text(effort.description)
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isSelected ? theme.appAccentSoftFill : Color.clear, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }
}
