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

    // Toggle 模型专用状态：是否启用思考
    @State private var localIsThinkingEnabled = false

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

    /// 当前选中模型对思考能力的支持级别。
    private var thinkingAndReasoning: LumiThinkingAndReasoning {
        selectedModelCapabilities?.thinkingAndReasoning ?? .unsupported
    }

    /// 是否存在多个推理档位（true → 渲染档位下拉按钮；false → 不渲染）。
    private var hasMultipleLevels: Bool {
        thinkingAndReasoning.hasMultipleLevels
    }

    /// 当前模型是否为 toggle 模式（仅有开关，无档位）。
    private var isToggleModel: Bool {
        thinkingAndReasoning == .toggle
    }

    /// 当前模型实际可用的推理档位（用于过滤下拉项）。
    private var availableEfforts: [LumiReasoningEffort] {
        LumiReasoningEffort.available(for: thinkingAndReasoning)
    }

    /// 多档模型：当前选中的档位（用于下拉按钮显示）。
    private var persistedEffort: LumiReasoningEffort {
        conversations?.reasoningEffort(for: selectedConversationID) ?? .defaultEffort
    }

    /// Toggle 模型专用：获取当前思考启用状态。
    private var persistedIsThinkingEnabled: Bool {
        conversations?.reasoningEffortOptional(for: selectedConversationID) != nil
    }

    var body: some View {
        Group {
            if isToggleModel {
                // Toggle 模型：显示简单的开关按钮
                Toggle(isOn: $localIsThinkingEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.system(size: 11, weight: .medium))
                        Text("思考")
                            .font(.appCaptionEmphasized)
                    }
                    .foregroundColor(theme.textSecondary)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .onChange(of: localIsThinkingEnabled) { _, enabled in
                    if enabled {
                        // 开启：使用 high 作为默认档位
                        selectEffort(.high)
                    } else {
                        // 关闭：清除推理设置
                        clearEffort()
                    }
                }
                .help(localIsThinkingEnabled ? "思考已开启，点击关闭" : "思考已关闭，点击开启")
            } else if hasMultipleLevels {
                // 多档模型：显示档位下拉按钮
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
                    ConversationReasoningPopover(
                        selectedEffort: localEffort,
                        availableEfforts: availableEfforts
                    ) { effort in
                        selectEffort(effort)
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
        .onChange(of: thinkingAndReasoning) { _, support in
            // 档位集合变化（例如 4 档 → 3 档、3 档 → toggle）时，重算 localEffort，
            // 确保按钮显示的档位仍在当前可用集合内。
            if support.hasMultipleLevels {
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

    /// 选择推理档位（非 nil 值，用于多档模型）
    private func selectEffort(_ effort: LumiReasoningEffort) {
        localEffort = effort
        conversations?.setReasoningEffort(effort, for: selectedConversationID)
    }

    /// 清除/关闭推理（用于 toggle 模型关闭时）
    private func clearEffort() {
        localIsThinkingEnabled = false
        conversations?.clearReasoningEffort(for: selectedConversationID)
    }

    private func syncFromConversation() {
        if isToggleModel {
            // Toggle 模型：同步开关状态
            localIsThinkingEnabled = persistedIsThinkingEnabled
        } else {
            // 多档模型：同步档位选择
            let persisted = persistedEffort
            // 如果对话持久化的档位不在当前模型支持列表里，回退到当前模型的第一个可用档位，
            // 避免出现"按钮显示 XHIGH 但下拉里没有该项"的撕裂。
            // 没有可用档位（unsupported）时保持当前 localEffort 不变。
            if availableEfforts.isEmpty {
                return
            } else if availableEfforts.contains(persisted) {
                localEffort = persisted
            } else {
                localEffort = availableEfforts.first ?? .defaultEffort
            }
        }
    }
}

private struct ConversationReasoningPopover: View {
    let selectedEffort: LumiReasoningEffort
    let availableEfforts: [LumiReasoningEffort]
    let onSelect: (LumiReasoningEffort) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reasoning Effort")
                .font(.appCaptionEmphasized)

            ForEach(availableEfforts) { effort in
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
