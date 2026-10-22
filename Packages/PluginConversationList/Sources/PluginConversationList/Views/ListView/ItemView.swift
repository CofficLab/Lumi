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
                Text(conversation.title ?? "对话")
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
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(automationLevelWatermark)
        .overlay(alignment: .topTrailing) {
            statusIndicator
        }
    }

    // MARK: - 自动化程度水印

    /// 自动化程度图标作为整张卡片的背景水印。
    ///
    /// ## 为什么做成背景而不是第三行的一枚图标
    ///
    /// 自动化等级只有三档（对话 / 构建 / 自主），是**整张卡片的属性**而不是
    /// 某一行的元信息。放在第三行末尾时，它既挤占了一行高度，又因为行尾
    /// 位置而被误读成「项目」或「时间」的一部分。
    ///
    /// 改为水印后：
    /// - 第三行只保留「项目 · 时间」，语义更纯粹；
    /// - 等级信息以背景存在，一眼扫过整列列表即可区分，无需逐行阅读文字。
    ///
    /// ## 为什么是「右对齐 + 轻微裁切」而不是铺满
    ///
    /// 卡片是**宽而矮**的（典型 340×62），而 SF Symbol 是正方形。若用
    /// `.fill` 铺满，图标会被放大到 340×340 再裁切，露出的只是中段一条色带 ——
    /// 完全认不出是哪个图标，等于白画。
    ///
    /// 因此改为：按 `fit` 等比缩放到略高于卡高（约 1.4×），右对齐并裁掉超出部分。
    /// 这样图标**完整可辨**（仍然是「自主」的盾牌），只是上下被切一点，
    /// 视觉上比卡内小图标更饱满，又不会像铺满那样退化成色块。
    ///
    /// ## 其他实现要点
    ///
    /// 1. `GeometryReader` 提供卡片实际尺寸 —— 卡片高度由文字决定、随内容变化，
    ///    写死尺寸会在长标题换行时错位。
    /// 2. `allowsHitTesting(false)` 保证水印不吞掉行的点击与右键菜单。
    /// 3. 透明度压到 `0.10`：水印只需在余光中提示等级，不能与标题争夺注意力。
    @ViewBuilder
    private var automationLevelWatermark: some View {
        if let level = conversation.automationLevel {
            GeometryReader { proxy in
                HStack {
                    Spacer()
                    Image(systemName: level.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: proxy.size.height * 1.4)
                        .foregroundStyle(watermarkColor(for: level))
                        .opacity(0.10)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
            .allowsHitTesting(false)
        }
    }

    /// 水印配色，与工具栏的等级 chip（`AutomationLevelToolbarView`）保持同一语义：
    /// 对话=青、构建=橙、自主=绿。
    private func watermarkColor(for level: AutomationLevel) -> Color {
        switch level {
        case .chat: .cyan
        case .build: .orange
        case .autonomous: .green
        }
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

/// 预览三档自动化等级下的会话卡片，用于目视检查水印效果。
#Preview("会话卡片 · 自动化等级水印") {
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
