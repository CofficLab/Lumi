import LumiUI
import ProviderConversation
import ProviderConversationState
import SwiftUI

/// 会话项视图
struct ItemView: View {
    @LumiTheme private var theme: any LumiUITheme

    let conversation: ConversationSummary
    let conversationState: ConversationStateSnapshot?
    let isSelected: Bool
    let needsAttention: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        AppListRow(isSelected: isSelected, action: {
            onSelect()
        }) {
            content
        }
        // Attach the menu to the row itself. Attaching it to `content` puts it
        // inside AppListRow's Button label, and the button consumes the
        // right-click before SwiftUI can present the menu on macOS.
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        // Important: 必须合并子元素并显式给出可访问性名称与标识。
        //
        // 此前本文件没有任何 accessibility 修饰，行是 `Button` 内嵌
        // `HStack`（标题 + provider + 模型 + 项目 + 时间等若干 `Text`）。
        // SwiftUI 不会为这种组合自动合成行级元素，结果是：
        //   - 屏幕阅读器用户**读不到会话标题**（真实无障碍缺陷）；
        //   - UI 测试无法按标题定位会话行，只能盲点坐标。
        // 两者是同一个根因，因此在这里一并修。
        //
        // - Note: label 用 `.combine` 把子文本拼进来，并额外显式赋值，
        //   保证标题一定出现在可访问性名称里（combine 在子元素过多时
        //   可能只截断拼接，标题必须由我们自己保证在场）。
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(ConversationListAccessibility.itemID)
        .accessibilityLabel(ConversationListAccessibility.rowLabel(for: conversation))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var content: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ConversationRowTitle.resolve(conversation.title))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let providerID = conversation.providerID {
                    HStack(spacing: 4) {
                        Text(providerID)
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)

                        if let modelName = conversation.modelName, !modelName.isEmpty {
                            Text("·")
                                .foregroundColor(theme.textTertiary)
                            Text(modelName)
                                .font(.footnote)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)
                }

                HStack(spacing: 4) {
                    if let projectPath = conversation.projectPath {
                        Text(URL(fileURLWithPath: projectPath).lastPathComponent)
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text("·")
                            .foregroundColor(theme.textTertiary)
                    }

                    Text(conversation.lastMessageAt.relativeTime)
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)

                    // 自动化程度：与「项目 · 时间」同处第三行，作为行内元信息展示。
                    if let automationLevel = conversation.automationLevel {
                        Text("·")
                            .foregroundColor(theme.textTertiary)

                        Label(automationLevel.displayName, systemImage: automationLevel.iconName)
                            .labelStyle(.titleAndIcon)
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) { statusIndicator }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if conversationState?.authorizationState == .required {
            stateIcon("exclamationmark.shield.fill", color: .orange)
        } else {
            switch conversationState?.agentLoopState {
            case .running:
                pulsingAttentionDot
            case .suspended:
                stateIcon("pause.circle.fill", color: .orange)
            case .failed:
                stateIcon("exclamationmark.triangle.fill", color: .red)
            case .completed, .cancelled, .idle, nil:
                if needsAttention { attentionDot }
            }
        }
    }

    private func stateIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.top, 3)
            .padding(.trailing, 2)
            .allowsHitTesting(false)
    }

    private var attentionDot: some View {
        dotCore(color: .green)
            .padding(.top, 3)
            .padding(.trailing, 2)
            .allowsHitTesting(false)
    }

    private var pulsingAttentionDot: some View {
        ZStack {
            dotCore(color: Color.accentColor)

            Circle()
                .stroke(Color.accentColor.opacity(0.75), lineWidth: 1)
                .frame(width: 6, height: 6)
                .phaseAnimator([false, true]) { ring, phase in
                    ring
                        .scaleEffect(phase ? 3.2 : 1)
                        .opacity(phase ? 0 : 0.75)
                } animation: { _ in
                    .easeOut(duration: 1.1)
                }
        }
        .frame(width: 22, height: 22)
        .padding(.top, -5)
        .padding(.trailing, -6)
        .allowsHitTesting(false)
    }

    private func dotCore(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}

// MARK: - 预览

/// 预览三档自动化等级下的会话卡片，用于目视检查第三行等级标签的显示效果。
#Preview("会话卡片 · 自动化等级") {
    VStack(spacing: 4) {
        ForEach(AutomationLevel.allCases) { level in
            ItemView(
                conversation: ConversationSummary(
                    id: UUID(),
                    title: "MiniMax 刷新模型后的默认上下文大小",
                    preview: "",
                    createdAt: Date(),
                    updatedAt: Date(),
                    verbosity: .standard,
                    reasoningEffort: nil,
                    language: .chinese,
                    automationLevel: level,
                    providerID: "minimax-tokenpl",
                    modelName: "MiniMax-M3.1-Fl",
                    projectPath: "/Users/colorfy/Code/CofficLab/Lumi",
                    parentConversationID: nil
                ),
                conversationState: nil,
                isSelected: false,
                needsAttention: false,
                onSelect: {},
                onDelete: {}
            )
        }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .frame(width: 340)
    .background(Color.gray.opacity(0.12))
}
