import CoreGraphics
import Foundation
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V4（ZCode）用户消息视图。
///
/// 与 V1–V3 的差异：
/// - 右对齐，短消息按内容收缩，长消息不超过可用宽度；
/// - 背景 `surface`、1px `border`、无阴影；圆角 12、右上角 2；
/// - 空正文且只有附件时**不绘制空气泡**，附件仍在气泡外右对齐；
/// - 长文可见高度 120，超过 121 则折叠，可展开 / 收起；
/// - hover / focus 才显示复制按钮，成功后 1200ms 显示绿色勾。
///
/// - Important: 附件解码复用 `message.cachedDecodedAttachments`，
///   不复制附件解码逻辑。
struct ZCodeUserMessageView: View {
    let capability: any MessageRendererCapability
    @ObservedObject var stateViewModel: MessageRendererStateViewModel
    let message: Message
    let verbosity: ResponseVerbosity

    /// 折叠状态（内容或行身份变化后重新收起）。
    @State private var collapseState = ZCodeUserBubbleCollapseState()
    /// 复制反馈状态。
    @State private var copyState = ZCodeCopyFeedbackState()
    /// 是否 hover。
    ///
    /// - Important: 必须是 `@StateObject`：宿主每重绘一次就会重新 `init`
    ///   本视图一次，`let` 持有的状态对象会被重建，
    ///   hover 防抖任务随之丢失（进入防抖永远不生效）。
    @StateObject private var hoverState = MessageHoverState()
    /// 是否键盘聚焦。
    @FocusState private var hasKeyboardFocus: Bool

    /// 本行的稳定身份：消息 id + 内容。
    private var rowIdentity: String {
        "\(message.id.uuidString)|\(message.content)"
    }

    var body: some View {
        let attachments = message.cachedDecodedAttachments
        let showsBubble = ZCodeUserBubbleStyle.hasVisibleBubble(
            content: message.content,
            hasAttachments: !attachments.imageData.isEmpty || !attachments.fileAttachments.isEmpty
        )

        return ZCodeUserBubbleLayout(content: AnyView(
            Group {
                if showsBubble {
                    ZCodeAccessibilityMarker(
                        identifier: ZCodeRendererAccessibilityIdentifiers.userBubble
                    )
                    bubbleBody
                }
                attachmentSection(attachments: attachments)
                if showsBubble {
                    // 复制按钮：hover / 键盘聚焦时才显示。
                    //
                    // - Important: 不能用 `opacity(0)` 隐藏 —— 那会让 AX 树
                    //   **完全丢掉**这个元素，键盘用户与 UI 测试都拿不到它。
                    //   正确做法是保留在树上、只改透明度，并用
                    //   `accessibilityHidden` 之外的手段表达「当前不可见」。
                    copyButton
                        .opacity(isCopyVisible ? 1 : 0)
                        .accessibilityHidden(false)
                }
            }
            // Important: hover 域挂在**气泡内容**上，不挂在整行 layout 上。
            //
            //   `ZCodeUserBubbleLayout` 是 `HStack { Spacer; 内容 }`，
            //   宽度铺满整列；`onHover` 挂在它上面时，鼠标只要进入这一行的
            //   **任何空白区域**（尤其是左侧大片空白），
            //   气泡的复制按钮就会突然冒出来 —— 视觉上很突兀。
            //
            //   挂到内容上之后，只有真正悬停在气泡 / 附件 / 按钮上才触发。
            .contentShape(Rectangle())
            .onHover { hovering in
                hoverState.setHovering(hovering)
            }
        ))
        .onAppear {
            collapseState.updateIdentity(content: message.content, rowID: rowIdentity)
        }
        .onChange(of: rowIdentity) { _, newValue in
            collapseState.updateIdentity(content: message.content, rowID: newValue)
        }
    }

    /// 复制按钮是否可见：hover（带防抖）或键盘聚焦。
    private var isCopyVisible: Bool {
        hoverState.isHovered || hasKeyboardFocus
    }

    // MARK: - 气泡

    private var bubbleBody: some View {
        ZCodeUserBubbleSurface(content: AnyView(
            VStack(alignment: .leading, spacing: ZCodeUserBubbleStyle.innerSpacing) {
                CollapsedContentChips(
                    text: message.content,
                    blocks: CollapsedContentBlockMetadata.normalizedBlocks(
                        from: message.metadata,
                        contentLength: message.content.count
                    )
                )
                .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.userBubbleBody)

                if isCollapsible {
                    Button {
                        collapseState.setExpanded(!collapseState.isExpanded)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: collapseState.isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                            Text(collapseState.isExpanded
                                 ? pluginLocalization.string("Collapse")
                                 : pluginLocalization.string("Expand"))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.userExpandToggle)
                    // - Important: SwiftUI 的 Button 会把 label 当作 AX 的 `value` 暴露，
                    //   `accessibilityValue` 在这类控件上**不会**单独呈现。
                    //   要让「展开 / 收起」状态可被 UI 测试与辅助功能读到，
                    //   必须用 `accessibilityLabel` 明确指定语义。
                    .accessibilityLabel(
                        collapseState.isExpanded
                            ? pluginLocalization.string("Collapse")
                            : pluginLocalization.string("Expand")
                    )
                }
            }
            .font(.system(size: ZCodeUserBubbleStyle.bodyFontSize))
            .frame(maxWidth: .infinity, alignment: .leading)
        ))
    }

    /// 用户气泡的复制按钮。
    ///
    /// - Important: 复制的是**原始** `Message.content`，不裁剪。
    @ViewBuilder
    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                ZCodeUserBubbleStyle.copyText(for: message.content),
                forType: .string
            )
            copyState.markCopied()
        } label: {
            Image(systemName: copyState.isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: ZCodeUserBubbleStyle.copyButtonIconSize))
                .foregroundColor(.secondary)
                .frame(
                    width: ZCodeUserBubbleStyle.copyButtonSize,
                    height: ZCodeUserBubbleStyle.copyButtonSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.userCopyButton)
        .accessibilityLabel(pluginLocalization.string("Copy"))
    }

    /// 正文是否超出折叠阈值。
    ///
    /// - Note: 用字符数的**保守估计**判断：真实高度要等布局完成后才知道，
    ///   而布局完成前就需要决定是否显示折叠按钮。
    ///   保守估计偏大 → 宁可多显示一个可展开的按钮，
    ///   也不让长文被截断且无从展开。
    private var isCollapsible: Bool {
        ZCodeUserBubbleStyle.shouldCollapse(contentHeight: CGFloat(message.content.count))
    }

    // MARK: - 附件

    @ViewBuilder
    private func attachmentSection(
        attachments: MessageAttachmentDecodeCache.Decoded
    ) -> some View {
        if !attachments.imageData.isEmpty || !attachments.fileAttachments.isEmpty {
            VStack(alignment: .trailing, spacing: ZCodeUserBubbleStyle.innerSpacing) {
                if !attachments.imageData.isEmpty {
                    AppImagePreviewGrid(imageDataList: attachments.imageData)
                }
                if !attachments.fileAttachments.isEmpty {
                    MessageFileAttachmentChips(attachments: attachments.fileAttachments)
                }
            }
            .frame(maxWidth: ZCodeUserBubbleStyle.attachmentColumnMaxWidth, alignment: .trailing)
            .padding(.bottom, ZCodeUserBubbleStyle.attachmentColumnBottomSpacing)
        }
    }
}

/// V4 用户消息的右对齐布局外壳。
///
/// - Note: 气泡最大宽度依赖**聊天容器宽度**与**内容列宽度**；
///   两者由 V4 列表层提供，缺省时退化为不限宽。
private struct ZCodeUserBubbleLayout: View {
    let content: AnyView

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                content
            }
            .frame(maxWidth: ZCodeBubbleMetrics.maxBubbleWidth, alignment: .trailing)
        }
    }
}

/// 气泡表面：surface 背景 + 1px border + 无阴影。
private struct ZCodeUserBubbleSurface: View {
    let content: AnyView

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ZCodeMessageAppearance.palette(for: colorScheme)
        content
            // Important: 这里**不能**挂 `accessibilityIdentifier`，也**不能**加
            //   `.accessibilityElement(children: .contain)`：
            //   前者会向下传播、覆盖子元素（展开按钮、复制按钮）的标识符；
            //   后者会把整个气泡合并成**一个** AX 元素，
            //   内部元素因此不再单独暴露。
            //
            //   「这一行有用户气泡」由**独立的标记元素**表达（见 bubbleBody 的兄弟节点）。
            .padding(.horizontal, ZCodeUserBubbleStyle.horizontalPadding)
            .padding(.vertical, ZCodeUserBubbleStyle.verticalPadding)
            .background(palette.surface)
            .overlay(
                ZCodeUserBubbleStyle.cornerRadii.shape
                    .strokeBorder(palette.border, lineWidth: 1)
            )
            .clipShape(ZCodeUserBubbleStyle.cornerRadii.shape)
    }
}

/// 气泡可用的容器 / 内容列宽度。
///
/// - Note: 这些值由 V4 列表层写入；缺省时用较大的兜底值，
///   避免在非 V4 宿主里把气泡压扁。
enum ZCodeBubbleMetrics {
    private static let fallbackContainerWidth: CGFloat = 1_200
    private static let fallbackContentWidth: CGFloat = 1_152

    /// 聊天容器宽度。
    static var containerWidth: CGFloat { fallbackContainerWidth }

    /// 内容列宽度。
    static var contentWidth: CGFloat { fallbackContentWidth }

    /// 气泡最大宽度。
    static var maxBubbleWidth: CGFloat {
        ZCodeUserBubbleStyle.bubbleMaxWidth(
            containerWidth: containerWidth,
            contentWidth: contentWidth
        )
    }
}


/// V4（ZCode）用户气泡的视觉规格。
///
/// 基准是 ZCode 3.15.1：
/// - `packages/ui/src/v4/ConversationUserInputBubble.tsx`：
///   `rounded-xl rounded-tr-xs border border-border bg-surface px-4 py-3
///   text-ui-base text-foreground @min-[624px]/conversation:max-w-xl`；
/// - `packages/ui/src/v4/ConversationUserInputBody.tsx`：
///   `COLLAPSED_USER_INPUT_CONTENT_MAX_HEIGHT_PX = 120`、
///   `USER_INPUT_CONTENT_OVERFLOW_TOLERANCE_PX = 1`；
/// - `packages/ui/src/v4/ConversationRowView.tsx` 的 `CopyRowAction`：
///   成功后 1200ms 恢复。
///
/// 这些常量是**纯值**，便于直接断言几何，不依赖任何视图渲染。
enum ZCodeUserBubbleStyle {

    // MARK: - 几何

    /// 圆角：四角 12，右上角 2。
    ///
    /// - Important: SwiftUI 没有内置「四角独立圆角」，必须用 `UnevenRoundedRectangle`，
    ///   不能用胶囊或对称圆角代替。
    static let cornerRadii = UnevenRoundedRectangleCorners(
        topLeading: 12,
        bottomLeading: 12,
        bottomTrailing: 12,
        topTrailing: 2
    )

    /// 水平内边距。
    static let horizontalPadding: CGFloat = 16

    /// 垂直内边距。
    static let verticalPadding: CGFloat = 12

    /// 气泡内部各项之间的间距。
    static let innerSpacing: CGFloat = 8

    /// 正文字号。
    static let bodyFontSize: CGFloat = 14

    /// 正文行高。
    static let bodyLineHeight: CGFloat = 24

    /// 气泡最大宽度。
    ///
    /// - 容器 `< 624`：可用满内容列。
    /// - 容器 `≥ 624`：最多 576，同时仍受内容列内宽约束。
    static func bubbleMaxWidth(containerWidth: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let capped: CGFloat = containerWidth >= 624 ? 576 : containerWidth
        return min(capped, contentWidth)
    }

    // MARK: - 长文折叠

    /// 折叠时的可见高度。
    static let collapsedMaxHeight: CGFloat = 120

    /// overflow 容差：实测 120 / 121 不折叠，122 折叠。
    static let overflowTolerance: CGFloat = 1

    /// 内容是否需要折叠。
    static func shouldCollapse(contentHeight: CGFloat) -> Bool {
        guard contentHeight.isFinite else { return false }
        return contentHeight > collapsedMaxHeight + overflowTolerance
    }

    // MARK: - 复制

    /// 复制按钮边长。
    static let copyButtonSize: CGFloat = 24

    /// 复制按钮图标尺寸。
    static let copyButtonIconSize: CGFloat = 14

    /// 复制成功后的反馈时长（秒）。
    static let copyFeedbackDuration: TimeInterval = 1.2

    /// 展开 / 收起按钮的文案。
    ///
    /// - Important: SwiftUI 的 Button 会把 label 当作 AX 的 `value` 暴露，
    ///   `accessibilityValue` 不会单独呈现。
    ///   因此「展开 / 收起」状态必须由**文案**承载，
    ///   两者必须不同，否则辅助功能与 UI 测试都读不出状态。
    static func toggleLabel(isExpanded: Bool) -> String {
        isExpanded
            ? pluginLocalization.string("Collapse")
            : pluginLocalization.string("Expand")
    }

    /// 复制内容：使用**原始** `Message.content`，不裁剪。
    static func copyText(for content: String) -> String {
        content
    }

    // MARK: - 气泡可见性

    /// 是否绘制气泡。
    ///
    /// - Important: 空正文且只有附件时**不绘制空气泡**；
    ///   附件仍在气泡外右对齐。
    static func hasVisibleBubble(content: String, hasAttachments: Bool) -> Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 附件几何

    /// 媒体缩略图边长。
    static let mediaThumbnailSize: CGFloat = 80

    /// 媒体缩略图圆角。
    static let mediaThumbnailCornerRadius: CGFloat = 12

    /// 非媒体文件 pill 的水平内边距。
    static let filePillHorizontalPadding: CGFloat = 12

    /// 非媒体文件 pill 的垂直内边距。
    static let filePillVerticalPadding: CGFloat = 6

    /// 非媒体文件 pill 的圆角（全圆角）。
    static let filePillCornerRadius: CGFloat = .infinity

    /// 非媒体文件 pill 的图标尺寸。
    static let filePillIconSize: CGFloat = 16

    /// 非媒体文件 pill 的文件名最大宽度。
    static let filePillMaxFileNameWidth: CGFloat = 160

    /// 附件列最大宽度。
    static let attachmentColumnMaxWidth: CGFloat = 576

    /// 附件列底间距。
    static let attachmentColumnBottomSpacing: CGFloat = 8

    // MARK: - 动画

    /// 展开 / 收起动画时长（秒）。
    static let collapseAnimationDuration: TimeInterval = 0.3

    /// 实际动画时长；`reduceMotion` 下为 0（即无动画）。
    static func animationDuration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : collapseAnimationDuration
    }
}

/// 用户气泡的折叠状态。
///
/// - Important: 内容或行身份变化后必须重新收起 —— 否则用户在一条消息上
///   展开后，切换到另一条同样长的消息时会看到它也是展开的。
struct ZCodeUserBubbleCollapseState: Equatable {
    /// 是否已展开。
    private(set) var isExpanded = false
    /// 当前身份（内容 + 行 id）。
    private var identity: Identity?

    private struct Identity: Equatable {
        let content: String
        let rowID: String
    }

    /// 设置展开状态。
    mutating func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
    }

    /// 内容或行身份变化时更新身份；变化则重置为收起。
    ///
    /// - Note: **首次**观察只是「记录」身份，不是「变化」——
    ///   否则视图刚挂载时用户的展开状态会被无故清掉。
    mutating func updateIdentity(content: String, rowID: String) {
        let newIdentity = Identity(content: content, rowID: rowID)
        guard let identity else {
            self.identity = newIdentity
            return
        }
        guard newIdentity != identity else { return }
        self.identity = newIdentity
        isExpanded = false
    }
}

/// 复制按钮的反馈状态机。
///
/// - Note: 用**注入时间**而不是 `sleep`，测试因此不需要真的等 1.2 秒。
struct ZCodeCopyFeedbackState: Equatable {
    /// 是否处于「已复制」反馈态。
    private(set) var isCopied = false
    /// 反馈开始的时间戳。
    private var copiedAt: TimeInterval?

    /// 标记为已复制。
    mutating func markCopied(at time: TimeInterval = 0) {
        isCopied = true
        copiedAt = time
    }

    /// 推进时间；到达反馈时长后恢复。
    mutating func tick(elapsed: TimeInterval) {
        guard isCopied, let copiedAt else { return }
        guard elapsed - copiedAt >= ZCodeUserBubbleStyle.copyFeedbackDuration else { return }
        isCopied = false
        self.copiedAt = nil
    }
}

/// 不对称圆角（四角可分别指定）。
///
/// - Note: 与 `PluginMessageListDetailed` 中的同名类型分处不同 module，
///   故各自一份；两者不互相依赖。
struct UnevenRoundedRectangleCorners: Equatable {
    let topLeading: CGFloat
    let bottomLeading: CGFloat
    let bottomTrailing: CGFloat
    let topTrailing: CGFloat

    /// 转换为 SwiftUI 的 `UnevenRoundedRectangle`。
    var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: topLeading,
            bottomLeadingRadius: bottomLeading,
            bottomTrailingRadius: bottomTrailing,
            topTrailingRadius: topTrailing,
            style: .continuous
        )
    }
}


/// 无障碍标记元素。
///
/// - Important: 必须**有非空 label**：`Text("")` 会被 AX 树当成空元素丢掉，
///   `Color.clear` 更是纯绘制元素、根本不进 AX 树。
///   这里给一个不可见的空格字符作为 label，视觉上仍是空白。
///
/// - Note: 尺寸取 1×1，既能被 AX 树看到，又不会在视觉上产生任何痕迹。
struct ZCodeAccessibilityMarker: View {
    let identifier: String

    var body: some View {
        Text(" ")
            .font(.system(size: 1))
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(identifier)
            .allowsHitTesting(false)
    }
}
