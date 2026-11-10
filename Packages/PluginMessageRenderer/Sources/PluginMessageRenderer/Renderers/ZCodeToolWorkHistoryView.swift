import CoreGraphics
import Foundation
import ProviderConversation
import ProviderMessage
import SwiftUI

/// V4（ZCode）工作工具历史的呈现规格。
///
/// 基准是 ZCode 3.15.1 计划第 2.6 节：
/// - 两个及以上连续 Explore/Execute 才形成父分组；单工具不额外套父层；
/// - ZCode 默认：Explore=true、Execute/Terminal=true、Changes=false、CUA=true；
///   Lumi 只映射**真实存在**的工具类型，找不到等价语义时保持独立工具行；
/// - 共享嵌套容器：左 margin 8、左边框、左 padding 14、子项间距 8；
/// - 摘要 14，图标通常 16，项间距 8，默认收起；
/// - 展开内容与摘要间距 8；收起后 300ms 卸载重内容；
/// - Execute 摘要 command 用 sans；展开命令 mono 且带 `$`；
/// - Execute 输出 mono 14/20，最多 5 行内部滚动；离底超过 8 后停止输出跟随；
/// - Read 不展开结果；Edit 可展开 inline diff，最大高 240；通用工具预览最大高 240。
enum ZCodeToolWorkHistoryStyle {

    // MARK: - 几何

    /// 嵌套容器左 margin。
    static let containerLeadingMargin: CGFloat = 8

    /// 嵌套容器左 padding。
    static let containerLeadingPadding: CGFloat = 14

    /// 子项间距。
    static let itemSpacing: CGFloat = 8

    /// 摘要字号。
    static let summaryFontSize: CGFloat = 14

    /// 图标尺寸。
    static let iconSize: CGFloat = 16

    /// 展开内容与摘要的间距。
    static let expandedContentSpacing: CGFloat = 8

    /// 收起后卸载重内容的延迟（秒）。
    static let unloadDelay: TimeInterval = 0.3

    // MARK: - Execute

    /// Execute 输出最多显示的行数。
    static let executeOutputMaxLines: Int = 5

    /// Execute 输出离底超过该距离后停止跟随。
    static let executeOutputFollowThreshold: CGFloat = 8

    /// Execute 输出字号。
    static let executeOutputFontSize: CGFloat = 14

    /// Execute 输出行高。
    static let executeOutputLineHeight: CGFloat = 20

    /// Execute 输出是否等宽。
    static let executeOutputIsMonospaced = true

    // MARK: - 其它

    /// Edit 的 inline diff 最大高度。
    static let editDiffMaxHeight: CGFloat = 240

    /// 通用工具预览最大高度。
    static let genericPreviewMaxHeight: CGFloat = 240

    /// 展开的命令是否等宽。
    static let expandedCommandIsMonospaced = true

    // MARK: - 工具名映射

    /// 可参与父分组的工具家族。
    ///
    /// - Note: ZCode 的默认值是 Explore=true、Execute/Terminal=true、Changes=false、CUA=true。
    ///   Lumi 只映射**真实存在**的工具类型；找不到等价语义时保持独立工具行，
    ///   绝不按数组下标猜类型。
    private static let groupableToolNames: Set<String> = ["explore", "execute", "terminal"]

    /// 工具名是否属于可分组家族。
    static func isGroupableFamily(toolName: String) -> Bool {
        groupableToolNames.contains(toolName.lowercased())
    }

    /// 一批工具是否应形成父分组。
    ///
    /// - Important: 只有**全部**属于可分组家族、且数量 ≥ 2 时才分组。
    ///   单工具不额外套父层。
    static func shouldGroup(tools: [MessageToolCall]) -> Bool {
        guard tools.count >= 2 else { return false }
        return tools.allSatisfy { isGroupableFamily(toolName: $0.name) }
    }

    /// 工具是否可展开结果。
    ///
    /// - Read 不展开结果；Edit 可展开 inline diff。
    static func expandsResult(toolName: String) -> Bool {
        switch toolName.lowercased() {
        case "read": return false
        case "edit": return true
        default: return false
        }
    }

    // MARK: - 命令文本

    /// 展开时的命令文本：等宽且带 `$` 前缀。
    static func expandedCommandText(_ command: String) -> String {
        "$ \(command)"
    }

    /// 摘要里的命令文本：原样，不带 `$` 前缀（摘要用 sans）。
    static func summaryCommandText(_ command: String) -> String {
        command
    }

    // MARK: - 卸载

    /// 收起后是否应卸载重内容。
    static func shouldUnloadHeavyContent(isExpanded: Bool) -> Bool {
        !isExpanded
    }
}

/// V4（ZCode）工作工具历史视图。
///
/// - Important: 工具行的**内容**继续由真实的 `ToolCallRowRenderer` 与 capability
///   提供；本视图只负责 ZCode 的分组与折叠外壳。
///   绝不用静态 ZCode 文案替换真实状态（授权、结果补全都保持真实）。
struct ZCodeToolWorkHistoryView: View {
    let capability: any MessageRendererCapability
    @ObservedObject var stateViewModel: MessageRendererStateViewModel
    let message: Message
    let verbosity: ResponseVerbosity
    /// 本组的工具调用。
    let toolCalls: [MessageToolCall]

    @State private var isExpanded = false
    /// 收起后延迟卸载重内容。
    @State private var isHeavyContentUnloaded = false
    @State private var isKeyboardFocused = false
    /// 参数弹层当前展开的工具调用 id。
    @State private var parameterPopoverToolCallID: String?
    /// 结果弹层当前展开的工具调用 id。
    @State private var resultPopoverToolCallID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
            if isExpanded && !isHeavyContentUnloaded {
                expandedContent
                    .padding(.top, ZCodeToolWorkHistoryStyle.expandedContentSpacing)
            }
        }
        .padding(.leading, ZCodeToolWorkHistoryStyle.containerLeadingMargin)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1)
        }
        // Important: 标识符**不能**挂在分组容器上：
        //   SwiftUI 会把它向下传播给子元素，
        //   展开按钮的标识符就被覆盖成 `work-history`。
        //   「这一组存在」改由**独立的标记元素**表达。
        .overlay(alignment: .topLeading) {
            ZCodeAccessibilityMarker(
                identifier: ZCodeRendererAccessibilityIdentifiers.workHistory
            )
        }
        .accessibilityElement(children: .contain)
        .task(id: isExpanded) {
            // 收起后 300ms 卸载重内容，避免折叠动画期间闪烁。
            if !isExpanded {
                try? await Task.sleep(for: .seconds(ZCodeToolWorkHistoryStyle.unloadDelay))
                guard !Task.isCancelled else { return }
                isHeavyContentUnloaded = true
            } else {
                isHeavyContentUnloaded = false
            }
        }
    }

    // MARK: - 摘要

    private var summaryRow: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: ZCodeToolWorkHistoryStyle.iconSize))
                    .foregroundColor(.secondary)
                Text(summaryText)
                    .font(.system(size: ZCodeToolWorkHistoryStyle.summaryFontSize))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.workHistoryToggle)
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isButton)
        .focusable()
    }

    /// 摘要文本：工具名与数量。
    private var summaryText: String {
        let names = toolCalls.map(\.name).joined(separator: ", ")
        return names.isEmpty ? "" : names
    }

    // MARK: - 展开内容

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: ZCodeToolWorkHistoryStyle.itemSpacing) {
            ForEach(toolCalls) { toolCall in
                // 复用真实的工具行渲染（含授权状态与结果补全）。
                ToolCallRowView(
                    capability: capability,
                    stateViewModel: stateViewModel,
                    message: message,
                    toolCall: toolCall,
                    verbosity: verbosity,
                    showsDetails: true,
                    parameterPopoverToolCallID: $parameterPopoverToolCallID,
                    resultPopoverToolCallID: $resultPopoverToolCallID
                )
            }
        }
        .padding(.leading, ZCodeToolWorkHistoryStyle.containerLeadingPadding)
    }
}
