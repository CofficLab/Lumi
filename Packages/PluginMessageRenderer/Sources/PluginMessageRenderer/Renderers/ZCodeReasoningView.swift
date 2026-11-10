import CoreGraphics
import Foundation
import ProviderMessage
import SwiftUI

/// V4（ZCode）reasoning 的呈现规格。
///
/// 基准是 ZCode 3.15.1 计划第 2.6 节：
/// - streaming 和 complete 默认均收起；streaming 且 text 为空不渲染；
/// - 完成时自动 collapse 不得覆盖用户显式展开/收起选择；
/// - Brain 图标 16；
/// - 只有真实时长字段语义匹配时才显示完成时长；不得用消息到达间隔伪造；
/// - streaming 收起时显示最后非空行摘要；
/// - 内容顶部间距 12、最大高 240、内部纵向滚动；
/// - 左 margin 8、左 padding 14、左边框；
/// - 内容是普通文本，不跑 Markdown；默认吸底，用户离底超过 2 后停止跟随。
enum ZCodeReasoningStyle {

    // MARK: - 可见性

    /// 是否渲染 reasoning。
    ///
    /// - Important: streaming 且文本为空时**不渲染** —— 空壳会留下无意义的间距。
    static func shouldRender(text: String, isStreaming: Bool) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }

    // MARK: - 几何

    /// 内容顶部间距。
    static let contentTopSpacing: CGFloat = 12

    /// 内容最大高度。
    static let contentMaxHeight: CGFloat = 240

    /// 内容左 margin。
    static let contentLeadingMargin: CGFloat = 8

    /// 内容左 padding。
    static let contentLeadingPadding: CGFloat = 14

    /// Brain 图标尺寸。
    static let brainIconSize: CGFloat = 16

    /// 吸底跟随阈值：离底超过该距离后停止跟随。
    static let followThreshold: CGFloat = 2

    // MARK: - 摘要

    /// streaming 收起时显示的最后非空行摘要。
    ///
    /// - Returns: 摘要文本；全空白时返回 nil。
    static func summary(text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.last
    }

    // MARK: - 时长

    /// 完成时长文案。
    ///
    /// - Parameter durationMilliseconds: **真实**的时长字段（毫秒）。
    ///   不得用消息到达间隔伪造。
    /// - Returns: 时长文案；没有真实字段或字段非正时返回 nil。
    static func durationText(durationMilliseconds: Int?) -> String? {
        guard let durationMilliseconds, durationMilliseconds > 0 else { return nil }
        let seconds = Double(durationMilliseconds) / 1000
        if seconds < 1 {
            return "\(durationMilliseconds)ms"
        }
        return String(format: "%.1fs", seconds)
    }

    // MARK: - 状态键

    /// 单条 reasoning 的折叠状态键。
    ///
    /// - Important: 必须与 turn 级工作历史折叠的状态键**不同**，
    ///   否则折叠一个会连带影响另一个。
    static func collapseStateKey(turnKey: String, rowID: String) -> String {
        "zcode.reasoning.\(turnKey).\(rowID)"
    }

    /// turn 级工作历史折叠的状态键。
    static func turnCollapseStateKey(turnKey: String) -> String {
        "zcode.workhistory.\(turnKey)"
    }
}

/// V4（ZCode）reasoning 的折叠状态。
///
/// - Important: 用户**显式**的展开/收起选择优先于「完成时自动 collapse」。
///   因此必须记住用户是否做过显式选择。
struct ZCodeReasoningCollapseState: Equatable {
    /// 是否已展开。
    private(set) var isExpanded = false
    /// 用户是否做过显式选择。
    private(set) var hasExplicitChoice = false

    /// 用户显式设置展开状态。
    mutating func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        hasExplicitChoice = true
    }

    /// 完成时的自动收起。
    ///
    /// - Important: 用户做过显式选择时**不生效**。
    mutating func applyAutoCollapseOnCompletion() {
        guard !hasExplicitChoice else { return }
        isExpanded = false
    }
}

/// V4（ZCode）reasoning 视图。
///
/// - Important: 内容是**普通文本**，不跑 Markdown；
///   默认吸底，用户离底超过 2 后停止跟随。
struct ZCodeReasoningView: View {
    /// reasoning 正文。
    let text: String
    /// 是否仍在流式生成中。
    let isStreaming: Bool
    /// 真实时长（毫秒）；没有真实字段时为 nil。
    let durationMilliseconds: Int?

    @State private var collapseState = ZCodeReasoningCollapseState()
    @State private var isHovered = false
    @State private var hasKeyboardFocus = false

    var body: some View {
        if ZCodeReasoningStyle.shouldRender(text: text, isStreaming: isStreaming) {
            VStack(alignment: .leading, spacing: 0) {
                summaryRow
                if collapseState.isExpanded {
                    expandedContent
                }
            }
            .padding(.leading, ZCodeReasoningStyle.contentLeadingMargin)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)
            }
            // Important: 标识符**不能**挂在折叠块容器上：
            //   SwiftUI 会把它向下传播给子元素，
            //   展开按钮的标识符就被覆盖成 `reasoning`。
            //   「这一块存在」改由**独立的标记元素**表达。
            .overlay(alignment: .topLeading) {
                ZCodeAccessibilityMarker(
                    identifier: ZCodeRendererAccessibilityIdentifiers.reasoningBlock
                )
            }
            .accessibilityElement(children: .contain)
            .onChange(of: isStreaming) { _, streaming in
                // 完成时自动收起；用户显式选择优先，因此由状态机自行判断。
                if !streaming {
                    collapseState.applyAutoCollapseOnCompletion()
                }
            }
        }
    }

    // MARK: - 摘要

    private var summaryRow: some View {
        Button {
            collapseState.setExpanded(!collapseState.isExpanded)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .font(.system(size: ZCodeReasoningStyle.brainIconSize))
                    .foregroundColor(.secondary)
                Text(summaryText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if let duration = ZCodeReasoningStyle.durationText(durationMilliseconds: durationMilliseconds) {
                    Text(duration)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // macOS 的 SwiftUI 没有 `accessibilityExpanded`；
        // 用 `accessibilityValue` 暴露展开状态，语义等价。
        .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.reasoningToggle)
        .accessibilityValue(collapseState.isExpanded ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isButton)
        .focusable()
        .onHover { isHovered = $0 }
    }

    /// 收起时显示摘要；展开时显示固定文案。
    private var summaryText: String {
        if collapseState.isExpanded {
            return ZCodeReasoningStyle.summary(text: text) ?? ""
        }
        return ZCodeReasoningStyle.summary(text: text) ?? ""
    }

    // MARK: - 展开内容

    private var expandedContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, ZCodeReasoningStyle.contentLeadingPadding)
                .padding(.top, ZCodeReasoningStyle.contentTopSpacing)
        }
        .frame(maxHeight: ZCodeReasoningStyle.contentMaxHeight)
    }
}
