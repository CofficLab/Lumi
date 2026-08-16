import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import SwiftUI

/// 会话推理强度控制插件（low / medium / high / xhigh / max / 关闭）。
///
/// 复刻自旧版 `Plugins/ConversationReasoningPlugin`，新版简化实现：
/// - 在 Chat 分区 Action Bar leading 注册推理按钮；
/// - 弹出档位选择，写入 `ConversationManaging.reasoningEffort`；
/// - AgentLoop 每轮请求读取 `reasoningEffortOptional` 传给 LLM
///   （`LLMRequest.reasoningEffort`）。
///
/// 说明：旧版按「选中模型能力」动态过滤档位（unsupported / toggle /
/// threeLevel / fourLevel）；新版 `LLMModelInfo` 尚无该能力字段，
/// 此处直接提供全部档位，由供应商侧按能力映射（能力感知过滤可后续补）。
@MainActor
public final class ConversationReasoningPlugin: SuperPlugin {
    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.conversation-reasoning"
    public let order = 81

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Conversation Reasoning",
            description: "Reasoning effort control (low / medium / high / xhigh / max)",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            return
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).action-bar-button",
                order: 81,
                placement: .actionLeading
            ) {
                ReasoningActionBarButton(conversations: conversations)
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
    let conversations: any ConversationManaging

    @State private var isPopoverPresented = false

    /// 是否开启思考（nil = 关闭）。
    private var selectedEffort: LumiReasoningEffort? {
        if let id = conversations.selectedConversationID {
            return conversations.reasoningEffortOptional(for: id)
        }
        return conversations.globalReasoningEffort
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selectedEffort == nil ? .secondary : .accentColor)
                .padding(4)
        }
        .buttonStyle(.plain)
        .help("Reasoning Effort")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ReasoningPopover(selected: selectedEffort) { option in
                apply(option)
                isPopoverPresented = false
            }
        }
    }

    private func apply(_ option: ReasoningOption) {
        switch option {
        case .off:
            if let id = conversations.selectedConversationID {
                conversations.clearReasoningEffort(for: id)
            }
            conversations.setGlobalReasoningEffort(nil)
        case let .effort(effort):
            if let id = conversations.selectedConversationID {
                conversations.setReasoningEffort(effort, for: id)
            }
            conversations.setGlobalReasoningEffort(effort)
        }
    }
}

enum ReasoningOption: Equatable {
    case off
    case effort(LumiReasoningEffort)
}

private struct ReasoningPopover: View {
    let selected: LumiReasoningEffort?
    let onSelect: (ReasoningOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reasoning Effort")
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
                    Text("Off")
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

            ForEach(LumiReasoningEffort.allCases) { effort in
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
                        Text(effort.displayName)
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
