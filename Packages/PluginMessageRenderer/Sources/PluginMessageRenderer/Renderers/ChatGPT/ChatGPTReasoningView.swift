import CoreGraphics
import Foundation
import LumiLocalizationKit
import LumiUI
import ProviderMessage
import SwiftUI

/// V5（ChatGPT）reasoning 的呈现规格。
///
/// 基准是 V5 方案第 2.6 节：
/// - 标题为「正在思考…」或「已思考」，有**真实**时长时才显示时长；
/// - 完成后默认收起；
/// - 展开内容复用现有可选择文本、最大高 240 和内部滚动行为；
/// - 不把私有推理转成模型没有提供的摘要。
enum ChatGPTReasoningStyle {

    // MARK: - 可见性

    /// 是否渲染 reasoning。
    ///
    /// - Important: 文本为空时**不渲染** —— 空壳会留下无意义的间距。
    static func shouldRender(text: String, isStreaming: Bool) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 几何

    /// 内容最大高度。
    static let contentMaxHeight: CGFloat = 240

    /// Brain 图标尺寸。
    static let brainIconSize: CGFloat = 16

    /// 标题字号。
    static let titleFontSize: CGFloat = 13

    /// 时长字号。
    static let durationFontSize: CGFloat = 11

    // MARK: - 标题

    /// 标题文本。
    ///
    /// - Parameter isStreaming: 是否仍在生成。
    /// - Returns: 「正在思考…」或「已思考」。
    static func titleText(isStreaming: Bool) -> String {
        isStreaming
            ? pluginLocalization.string("正在思考…")
            : pluginLocalization.string("已思考")
    }

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
}

/// V5（ChatGPT）reasoning 的折叠状态。
///
/// - Important: 用户**显式**的展开/收起选择优先于「完成时自动 collapse」。
///   因此必须记住用户是否做过显式选择。
struct ChatGPTReasoningCollapseState: Equatable {
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

/// V5（ChatGPT）reasoning 视图。
///
/// - Important: 内容是**普通文本**，不跑 Markdown。
struct ChatGPTReasoningView: View {
    /// reasoning 正文。
    let text: String
    /// 是否仍在流式生成中。
    let isStreaming: Bool
    /// 真实时长（毫秒）；没有真实字段时为 nil。
    let durationMilliseconds: Int?

    @LumiTheme private var theme
    @State private var collapseState = ChatGPTReasoningCollapseState()

    var body: some View {
        if ChatGPTReasoningStyle.shouldRender(text: text, isStreaming: isStreaming) {
            VStack(alignment: .leading, spacing: 0) {
                summaryRow
                if collapseState.isExpanded {
                    expandedContent
                }
            }
            // Important: 标识符**不能**挂在折叠块容器上：
            //   SwiftUI 会把它向下传播给子元素，
            //   展开按钮的标识符就被覆盖成 `reasoning`。
            //   「这一块存在」改由**独立的标记元素**表达。
            .overlay(alignment: .topLeading) {
                ChatGPTAccessibilityMarker(
                    identifier: ChatGPTRendererAccessibilityIdentifiers.reasoningBlock
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
                    .font(.system(size: ChatGPTReasoningStyle.brainIconSize))
                    .foregroundColor(theme.textSecondary)
                Text(summaryText)
                    .font(.system(size: ChatGPTReasoningStyle.titleFontSize))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if let duration = ChatGPTReasoningStyle.durationText(
                    durationMilliseconds: durationMilliseconds
                ) {
                    Text(duration)
                        .font(.system(size: ChatGPTReasoningStyle.durationFontSize))
                        .foregroundColor(theme.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // macOS 的 SwiftUI 没有 `accessibilityExpanded`；
        // 用 `accessibilityValue` 暴露展开状态，语义等价。
        .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.reasoningToggle)
        .accessibilityValue(collapseState.isExpanded ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isButton)
        .focusable()
    }

    /// 收起时显示标题；展开时显示最后一行摘要。
    private var summaryText: String {
        if collapseState.isExpanded {
            return ChatGPTReasoningStyle.summary(text: text) ?? ""
        }
        return ChatGPTReasoningStyle.titleText(isStreaming: isStreaming)
    }

    // MARK: - 展开内容

    private var expandedContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(text)
                .font(.system(size: ChatGPTReasoningStyle.titleFontSize))
                .foregroundColor(theme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
        .frame(maxHeight: ChatGPTReasoningStyle.contentMaxHeight)
    }
}
