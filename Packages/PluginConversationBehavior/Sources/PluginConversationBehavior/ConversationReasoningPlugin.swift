import Foundation
import os
import KernelCore
import KitLLM
import LumiUI
import ProviderChatSection
import ProviderConversation
import ProviderLLMManager
import ProviderToast
import LumiLoggingKit
import SwiftUI

/// 会话推理强度控制插件（low / medium / high / xhigh / max / 关闭）。
///
/// 复刻自旧版 `Plugins/ConversationReasoningPlugin`，新版简化实现：
/// - 在 Chat 分区 Action Bar leading 注册推理按钮；
/// - 弹出档位选择，写入 `ConversationManaging.reasoningEffort`；
/// - AgentLoop 每轮请求读取 `reasoningEffortOptional` 传给 LLM
///   （`LLMRequest.reasoningEffort`）。
///
/// 档位与「关闭」的可选项按**当前模型的思考能力**裁剪：部分模型强制思考
/// （关不掉，只能降档），部分模型既不能关也不认档位参数。UI 与请求构建读
/// 同一份能力声明，避免「关了思考却仍有思考过程」。
@MainActor
public final class ConversationReasoningPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-reasoning", category: "ConversationReasoning")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.conversation-reasoning"
    public let order = 81
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-reasoning",
        name: "Conversation Reasoning",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, ConversationManaging from kernel")
            return
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).action-bar-button",
                order: 81,
                placement: .actionLeading
            ) {
                ReasoningActionBarButton(
                    conversations: conversations,
                    toast: kernel.resolveProvider((any ToastProviding).self),
                    llm: kernel.resolveProvider((any LLMManaging).self)
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).action-bar-button")
    }
}

/// 推理档位按钮：点击弹出档位/开关选择。
struct ReasoningActionBarButton: View {
    @LumiTheme private var theme
    let conversations: any ConversationManaging
    let toast: (any ToastProviding)?
    /// 用于读取当前模型的思考能力；缺失时按通用行为渲染菜单。
    let llm: (any LLMManaging)?

    @State private var isPopoverPresented = false
    @State private var refreshToken = 0
    @State private var observer: (any ConversationObserverHandle)?
    @State private var llmObserver: (any LLMManagerObserverHandle)?

    init(
        conversations: any ConversationManaging,
        toast: (any ToastProviding)? = nil,
        llm: (any LLMManaging)? = nil
    ) {
        self.conversations = conversations
        self.toast = toast
        self.llm = llm
    }

    /// 是否开启思考（nil = 关闭）。
    private var selectedEffort: ReasoningEffort? {
        if let id = conversations.selectedConversationID {
            return conversations.reasoningEffortOptional(for: id)
        }
        return conversations.globalReasoningEffort
    }

    /// 当前模型的思考能力声明；模型未声明时为 `nil`。
    private var capability: LLMReasoningCapability? {
        // 依赖 refreshToken：模型切换后能力要重新读取。
        _ = refreshToken
        guard let llm else { return nil }
        // 会话绑定的模型优先；New Chat（无选中会话）回落到全局选中模型。
        let modelID: LLMModelID?
        if let conversationID = conversations.selectedConversationID,
           let rawModelID = conversations.modelID(for: conversationID) {
            modelID = LLMModelID(rawValue: rawModelID)
        } else {
            modelID = llm.selectedModelID
        }
        guard let modelID else { return nil }
        return llm.modelRoute(for: modelID)?.modelInfo.reasoning
    }

    private var menuOptions: ReasoningMenuOptions {
        ReasoningMenuOptions.make(capability: capability)
    }

    /// chip 显示的档位：强制思考的模型上「关闭」实际是最低档位，
    /// 必须显示真实档位，否则会出现「显示关闭、请求里却在思考」。
    private var displayedEffort: ReasoningEffort? {
        menuOptions.effectiveEffort(for: selectedEffort)
    }

    /// 「关闭」在该模型上的真实语义说明。
    private var offNotice: String? {
        switch menuOptions.off {
        case .available:
            return nil
        case .degradedToEffort(let effort):
            return pluginLocalization.string("Always-thinking model: Off uses the lowest effort.")
                + " (\(effort.levelCode))"
        case .unsupported:
            return pluginLocalization.string("This model cannot turn thinking off.")
        }
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.appCallout)

                Text(ReasoningChipLabel.text(for: displayedEffort))
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
        .help(offNotice ?? pluginLocalization.string("Reasoning Effort"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ReasoningPopover(selected: selectedEffort, options: menuOptions, notice: offNotice) { option in
                apply(option)
                isPopoverPresented = false
            }
        }
        .onAppear {
            observer = conversations.addConversationObserver { event in
                switch event {
                case .providerChanged, .selected, .reasoningChanged, .created, .listChanged:
                    refreshToken += 1
                case .deleted, .updated, .markedActive, .verbosityChanged,
                     .automationChanged, .languageChanged:
                    break
                }
            }
            // 模型切换 / 模型池刷新后能力声明要重新读取。
            llmObserver = llm?.addObserver { _ in
                refreshToken += 1
            }
        }
        .onDisappear {
            observer?.cancel()
            observer = nil
            llmObserver?.cancel()
            llmObserver = nil
        }
    }

    func apply(_ option: ReasoningOption) {
        // 选中会话时只改该会话；只有 New Chat（无选中会话）才改全局默认值，
        // 否则调整一个已有会话会连带改掉之后新建会话的默认档位。
        switch option {
        case .off:
            if let id = conversations.selectedConversationID {
                conversations.clearReasoningEffort(for: id)
            } else {
                conversations.setGlobalReasoningEffort(nil)
            }
            ConversationBehaviorToast.show(
                toast,
                title: pluginLocalization.string("Reasoning Effort"),
                detail: pluginLocalization.string("Off"),
            )
        case let .effort(effort):
            if let id = conversations.selectedConversationID {
                conversations.setReasoningEffort(effort, for: id)
            } else {
                conversations.setGlobalReasoningEffort(effort)
            }
            ConversationBehaviorToast.show(
                toast,
                title: pluginLocalization.string("Reasoning Effort"),
                detail: effort.levelCode,
            )
        }
    }
}

enum ReasoningOption: Equatable {
    case off
    case effort(ReasoningEffort)
}

private struct ReasoningPopover: View {
    let selected: ReasoningEffort?
    let options: ReasoningMenuOptions
    /// 「关闭」在该模型上的真实语义说明。
    let notice: String?
    let onSelect: (ReasoningOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pluginLocalization.string("Reasoning Effort"))
                .font(.system(size: 12, weight: .semibold))

            // 关闭思考
            Button {
                onSelect(.off)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.slash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selected == nil ? .accentColor : .secondary)
                        .frame(width: 18)
                    Text(pluginLocalization.string("Off"))
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Spacer()
                    if selected == nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected == nil ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(options.off == .unsupported)
            .opacity(options.off == .unsupported ? 0.5 : 1)

            if let notice {
                Text(notice)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 26)
            }

            ForEach(options.efforts) { effort in
                Button {
                    onSelect(.effort(effort))
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: effort.iconName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selected == effort ? .accentColor : .secondary)
                            .frame(width: 18)
                        Text(effort.levelCode)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        Text(effort.localizedDisplayName())
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        if selected == effort {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(selected == effort ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 240)
    }
}
