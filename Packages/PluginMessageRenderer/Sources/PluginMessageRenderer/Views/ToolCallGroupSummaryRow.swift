import Foundation
import KitAgentTool
import LumiLocalizationKit
import LumiUI
import ProviderMessage
import SwiftUI

/// V2 工具调用组的**折叠态**：一行摘要，点击后在 popover 中展开全部调用。
///
/// - Note: 只在 V2（standard）出现。V1 与 V3 都保持逐条铺开，
///   判定见 `ToolCallGroupCollapsePolicy`。
///
/// 折叠态呈现的信息：
/// - 状态图标（执行中 / 失败 / 已完成）
/// - 摘要文案（数量 + 总耗时，文案规则见 `ToolStepGroupSummary`）
/// - 展开按钮
///
/// - Note: 摘要行使用**与工具行卡片一致**的卡片外观（背景 + 描边），
///   这样折叠前后视觉重量相当，不会出现「展开是一堆卡片、收起是一行小字」
///   的落差。
struct ToolCallGroupSummaryRow: View {
    @LumiTheme private var theme

    /// 组内工具调用（已解析结果后的快照）。
    let toolCalls: [MessageToolCall]
    /// popover 展开态的内容（逐条工具行）。
    let expandedContent: () -> AnyView

    @State private var isExpanded = false
    @State private var isHovering = false

    private var aggregateState: ToolCallResultVisualState {
        ToolStepGroupSummary.aggregateState(for: toolCalls)
    }

    private var summaryText: String {
        ToolStepGroupSummary.summaryText(for: toolCalls)
    }

    private var summaryColor: Color {
        aggregateState.isFailure ? theme.error : theme.textSecondary
    }

    var body: some View {
        HStack(spacing: 8) {
            statusIcon

            Text(summaryText)
                .font(.appCaption)
                .foregroundColor(aggregateState.isFailure ? theme.error : theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            AppIconButton(
                systemImage: "list.bullet.rectangle",
                tint: isExpanded ? theme.textPrimary : theme.textSecondary,
                size: .compact,
                isActive: isExpanded
            ) {
                isExpanded.toggle()
            }
            .help(pluginLocalization.string("查看工具调用"))
            .accessibilityIdentifier(ToolCallGroupAccessibility.expandButton)
        }
        .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
        .background(rowBackground)
        .overlay(rowBorder)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        // - Important: 必须显式 `children: .contain`。否则 SwiftUI 会把容器
        //   当作普通容器，把 identifier 传播给每一个后代（图标 / 摘要文本 /
        //   展开按钮），于是按 identifier 查询会一次命中 3 个元素，
        //   UI 测试无法用它判断「折叠了几组」。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ToolCallGroupAccessibility.summaryRow)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            expandedContent()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if aggregateState == .loading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: aggregateState.systemImage)
                .font(.appCaptionEmphasized)
                .foregroundColor(summaryColor)
                .frame(width: 14, height: 14)
        }
    }

    /// 卡片背景：与 `ToolCallRowView` 的 V2/V3 卡片保持同一套底色规则。
    private var rowBackground: some View {
        Group {
            if isHovering {
                aggregateState.isFailure ? theme.error.opacity(0.12) : theme.textPrimary.opacity(0.08)
            } else {
                aggregateState.isFailure ? theme.error.opacity(0.08) : theme.textSecondary.opacity(0.06)
            }
        }
    }

    /// 卡片描边：与 `ToolCallRowView` 的 V2/V3 卡片保持同一套描边规则。
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
                aggregateState.isFailure
                    ? theme.error.opacity(isHovering ? 0.45 : 0.28)
                    : isHovering ? theme.textPrimary.opacity(0.12) : theme.textTertiary.opacity(0.06),
                lineWidth: 1
            )
    }
}

/// popover 内的工具调用列表容器。
///
/// 宽度固定，与既有「调用参数 / 调用结果」popover（`ToolDetailPopoverView`，
/// 宽 500）保持一致，避免同一条消息里出现两种宽度的弹层。
///
/// ## 为什么必须有高度上限 + 滚动
///
/// 折叠组可能包含几十条工具调用（长回合里常见）。若只固定宽度而不限制高度，
/// popover 会被内容撑到超出屏幕高度，SwiftUI 的 popover 一旦超出屏幕就会被
/// **裁掉**（而不是自动加滚动条），底部那几条工具行既看不见也滚不到。
///
/// 因此这里给滚动区加固定的高度上限，让超出部分进入 `ScrollView`。
struct ToolCallGroupPopoverContent: View {
    @LumiTheme private var theme

    let toolCalls: [MessageToolCall]
    let rows: () -> AnyView

    /// 滚动区高度上限（不含标题与内边距）。
    ///
    /// 取值参考同项目其它弹层（`ASCChatToolbarPopoverView` 460、
    /// `ToolbarPopoverContent` 360）：既能一次看到十来条，又不至于顶到屏幕边缘。
    private static let maxContentHeight: CGFloat = 420

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            // - Important: 滚动只包住列表本身，标题栏固定不动。
            //   若把标题也放进 ScrollView，长列表滚动后用户会失去
            //   「这是工具调用列表」的上下文。
            ScrollView(.vertical) {
                rows()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
            }
            .frame(maxHeight: Self.maxContentHeight)
        }
        .padding(12)
        .frame(width: 500, alignment: .leading)
        .appSurface(style: .popover, cornerRadius: 12, borderColor: theme.divider)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ToolCallGroupAccessibility.popover)
    }

    /// 标题栏：图标 + 「工具调用」+ 数量。
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textSecondary)

            Text(pluginLocalization.string("工具调用"))
                .font(.appCallout)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 12)

            Text("\(toolCalls.count)")
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
                .monospacedDigit()
        }
    }
}

/// 工具调用折叠态的无障碍标识符。
///
/// UI 测试必须按标识符定位：摘要文案是随 `-AppleLanguages` 变化的本地化文本，
/// 且带动态后缀（耗时、失败数），按文案定位在非英文环境下必然失败。
enum ToolCallGroupAccessibility {
    /// 折叠态摘要行（可点击展开）。
    static let summaryRow = "lumi.tool-call-group.summary"

    /// 展开按钮。
    static let expandButton = "lumi.tool-call-group.expand"

    /// 展开后的 popover 内容容器。
    static let popover = "lumi.tool-call-group.popover"
}

/// 工具调用**行**的无障碍标识符。
///
/// 按**工具调用 id** 而非文案定位：行内文案是本地化文本，且会被
/// `lineLimit(1)` 截断（「正在读取文件…」这类前缀也会变），按文案定位
/// 在非英文环境或长描述下必然失败。
enum ToolCallRowAccessibility {
    /// 某条工具调用的行标题。
    static func row(_ toolCallID: String) -> String {
        "lumi.tool-call-row.\(toolCallID)"
    }
}
