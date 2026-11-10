import CoreGraphics
import Foundation
import LumiLocalizationKit
import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// V5（ChatGPT）工作工具历史的呈现规格。
///
/// 基准是 V5 方案第 2.6 节：
/// - 工具组显示**真实**工具数、运行状态和结果；
/// - 等待授权的工具必须可见且可交互，**不得**因默认折叠被隐藏；
/// - 两个及以上连续同类工具形成父分组；单工具保持独立工具行。
enum ChatGPTToolWorkHistoryStyle {

    // MARK: - 几何

    /// 摘要字号。
    static let summaryFontSize: CGFloat = 13

    /// 图标尺寸。
    static let iconSize: CGFloat = 16

    /// 子项间距。
    static let itemSpacing: CGFloat = 8

    /// 展开内容与摘要的间距。
    static let expandedContentSpacing: CGFloat = 8

    // MARK: - 工具名映射

    /// 可参与父分组的工具家族。
    ///
    /// - Note: Lumi 只映射**真实存在**的工具类型；
    ///   找不到等价语义时保持独立工具行，绝不按数组下标猜类型。
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

    // MARK: - 授权可见性

    /// 该工具组里是否存在**等待用户授权**的工具。
    ///
    /// - Important: 等待授权的工具**必须**保持可见且可交互，
    ///   不得因默认折叠被隐藏 —— 否则用户看不到「需要我批准」这件事。
    /// - Note: 只依据**真实**的 `authorizationState` 与结果字段判断，
    ///   不猜测。
    static func containsPendingAuthorization(tools: [MessageToolCall]) -> Bool {
        tools.contains { toolCall in
            let isAwaiting = toolCall.result?.awaitingUserResponse == true
            let hasPendingState = toolCall.authorizationState?
                .localizedCaseInsensitiveContains("pending") == true
            return isAwaiting || hasPendingState
        }
    }

    /// 工具组默认是否应该展开。
    ///
    /// - Important: 有等待授权的工具时**必须**默认展开，
    ///   否则用户看不到需要交互的内容。
    static func defaultExpanded(tools: [MessageToolCall]) -> Bool {
        containsPendingAuthorization(tools: tools)
    }

    // MARK: - 摘要

    /// 摘要文本：工具名与真实数量。
    ///
    /// - Note: 数量来自**真实**的 `toolCalls`，不伪造。
    static func summaryText(toolNames: [String], toolCount: Int) -> String {
        let names = toolNames.joined(separator: ", ")
        guard !names.isEmpty else { return "" }
        // - Note: `pluginLocalization.string` 不支持插值参数，
        //   因此数量以**真实**数值直接拼接，不走格式化。
        let count = pluginLocalization.string("工具")
        return "\(names) · \(count) \(toolCount)"
    }
}

/// V5（ChatGPT）工作工具历史视图。
///
/// - Important: 工具行的**内容**继续由真实的 `ToolCallRowRenderer` 与 capability
///   提供；本视图只负责 V5 的分组与折叠外壳。
///   绝不用静态文案替换真实状态（授权、结果补全都保持真实）。
struct ChatGPTToolWorkHistoryView: View {
    let capability: any MessageRendererCapability
    @ObservedObject var stateViewModel: MessageRendererStateViewModel
    let message: Message
    let verbosity: ResponseVerbosity
    /// 本组的工具调用。
    let toolCalls: [MessageToolCall]

    @LumiTheme private var theme
    @State private var isExpanded: Bool
    /// 参数弹层当前展开的工具调用 id。
    @State private var parameterPopoverToolCallID: String?
    /// 结果弹层当前展开的工具调用 id。
    @State private var resultPopoverToolCallID: String?

    init(
        capability: any MessageRendererCapability,
        stateViewModel: MessageRendererStateViewModel,
        message: Message,
        verbosity: ResponseVerbosity,
        toolCalls: [MessageToolCall]
    ) {
        self.capability = capability
        self.stateViewModel = stateViewModel
        self.message = message
        self.verbosity = verbosity
        self.toolCalls = toolCalls
        // 有等待授权的工具时默认展开 —— 授权必须可见。
        _isExpanded = State(initialValue: ChatGPTToolWorkHistoryStyle.defaultExpanded(tools: toolCalls))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
            if isExpanded {
                expandedContent
                    .padding(.top, ChatGPTToolWorkHistoryStyle.expandedContentSpacing)
            }
        }
        // Important: 标识符**不能**挂在分组容器上：
        //   SwiftUI 会把它向下传播给子元素，
        //   展开按钮的标识符就被覆盖成 `work-history`。
        //   「这一组存在」改由**独立的标记元素**表达。
        .overlay(alignment: .topLeading) {
            ChatGPTAccessibilityMarker(
                identifier: ChatGPTRendererAccessibilityIdentifiers.workHistory
            )
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - 摘要

    private var summaryRow: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: ChatGPTToolWorkHistoryStyle.iconSize))
                    .foregroundColor(theme.textSecondary)
                Text(summaryText)
                    .font(.system(size: ChatGPTToolWorkHistoryStyle.summaryFontSize))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.workHistoryToggle)
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isButton)
        .focusable()
    }

    /// 摘要文本：工具名与数量。
    private var summaryText: String {
        ChatGPTToolWorkHistoryStyle.summaryText(
            toolNames: toolCalls.map(\.name),
            toolCount: toolCalls.count
        )
    }

    // MARK: - 展开内容

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: ChatGPTToolWorkHistoryStyle.itemSpacing) {
            ForEach(toolCalls) { toolCall in
                // 复用真实的工具行渲染（含授权状态与结果补全）。
                ToolCallRowView(
                    capability: capability,
                    stateViewModel: stateViewModel,
                    message: message,
                    toolCall: toolCall,
                    verbosity: verbosity,
                    showsDetails: true,
                    // V5 的工具行是**扁平**的 —— 不带 V2/V3 的
                    //   持续卡片底色与描边，避免 hover 时整行「突然亮起来」。
                    appearance: .flat,
                    parameterPopoverToolCallID: $parameterPopoverToolCallID,
                    resultPopoverToolCallID: $resultPopoverToolCallID
                )
            }
        }
    }
}
