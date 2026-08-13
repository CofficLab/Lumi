import KernelLumi
import AgentToolKit
import KernelLumi
import LumiUI
import SwiftUI

// MARK: - ToolCallRowsView
/// V1 (brief) 模式：纯文本 inline 样式，完全融入消息正文；
/// V2/V3 模式：带图标/背景/边框/按钮的卡片行。

struct ToolCallRowsView: View {
    let kernel: KernelLumi
    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    @State private var parameterPopoverToolCallID: String?
    @State private var resultPopoverToolCallID: String?
    @State private var resolvedToolCalls: [LumiToolCall]?

    private var toolCalls: [LumiToolCall] {
        resolvedToolCalls ?? message.toolCalls ?? []
    }

    private var rowContext: ToolCallRowMessageContext {
        ToolCallRowMessageContext(
            conversationId: message.conversationID,
            assistantMessageId: message.id,
            verbosityRawValue: verbosity.rawValue
        )
    }

    var body: some View {
        Group {
            if verbosity == .brief {
                // V1:ChatGPT 风格的「可折叠工具步骤组」——进行中展开,完成后收起成一行摘要。
                CollapsibleToolStepGroup(
                    kernel: kernel,
                    message: message,
                    toolCalls: message.toolCalls ?? [],
                    verbosity: verbosity
                )
            } else {
                lumiCardRows
            }
        }
        .task {
            guard verbosity != .brief else { return }
            await resolveResults()
        }
    }

    @MainActor
    private func resolveResults() async {
        guard let manager = kernel.toolManager else { return }
        var resolved = message.toolCalls ?? []
        for index in resolved.indices where resolved[index].result == nil {
            resolved[index].result = await manager.toolCallResult(for: resolved[index].id)
        }
        resolvedToolCalls = resolved
    }

    private var lumiCardRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toolCalls) { toolCall in
                toolCallRow(for: toolCall)
            }
        }
    }

    @ViewBuilder
    private func toolCallRow(for toolCall: LumiToolCall) -> some View {
        if let customRenderer = ToolCallRowRendererRegistry.shared.findRenderer(for: toolCall.agentToolCall) {
            customRenderer.render(
                toolCall: toolCall.agentToolCall,
                message: rowContext
            )
        } else {
            ToolCallRowView(
                kernel: kernel,
                message: message,
                toolCall: toolCall,
                verbosity: verbosity,
                showsDetails: verbosity != .brief,
                parameterPopoverToolCallID: $parameterPopoverToolCallID,
                resultPopoverToolCallID: $resultPopoverToolCallID
            )
        }
    }
}

// MARK: - ToolCallRowView

/// 单个工具调用卡片行。供 `ToolCallRowsView`(V2/V3)与
/// `CollapsibleToolStepGroup`(V1 展开态)共用,故为 internal。
struct ToolCallRowView: View {
    @LumiTheme private var theme

    let kernel: KernelLumi
    let message: LumiChatMessage
    let toolCall: LumiToolCall
    let verbosity: LumiResponseVerbosity
    /// 是否显示执行时长与参数/结果按钮。
    /// - 旧路径(ToolCallRowsView):V1 false / V2·V3 true。
    /// - V1 可折叠步骤组展开态:强制 `true`,让用户在 brief 下也能查看耗时与结果。
    let showsDetails: Bool
    @Binding var parameterPopoverToolCallID: String?
    @Binding var resultPopoverToolCallID: String?

    @State private var isHovering = false

    private var isParametersPresented: Bool {
        parameterPopoverToolCallID == toolCall.id
    }

    private var isResultsPresented: Bool {
        resultPopoverToolCallID == toolCall.id
    }

    private var isLoadingResult: Bool {
        toolCall.result == nil
    }

    /// 动作行展示文案：使用工具生成的语义化描述，并根据执行状态加上
    /// 「正在…/已完成」前缀，读起来更接近自然语言。
    private var actionTitle: String {
        let description = toolCall.displayDescription ?? "执行工具"
        return isLoadingResult ? "正在\(description)…" : description
    }

    private var visualState: ToolCallResultVisualState {
        ToolCallResultVisualState(result: toolCall.result, isLoading: isLoadingResult)
    }

    var body: some View {
        Group {
            if let customRenderer = ToolCallRowRendererRegistry.shared.findRenderer(for: toolCall.agentToolCall) {
                customRenderer.render(
                    toolCall: toolCall.agentToolCall,
                    message: ToolCallRowMessageContext(
                        conversationId: message.conversationID,
                        assistantMessageId: message.id,
                        verbosityRawValue: verbosity.rawValue
                    )
                )
            } else {
                defaultToolCallRow
            }
        }
    }

    private var defaultToolCallRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.appCaptionEmphasized)
                    .foregroundColor(visualState.isFailure ? theme.error : theme.textSecondary)

                Text(actionTitle)
                    .font(.appCaption)
                    .foregroundColor(visualState.isFailure ? theme.error : theme.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // V2/V3 显示执行时长
            if showsDetails, let duration = toolCall.result?.duration {
                Text(MessageViewHelpers.formatDuration(duration))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }

            // V2/V3 显示参数和结果按钮
            if showsDetails {
                parameterButton

                resultButton
            }
        }
        .modifier(ToolCallRowContainerModifier(
            showsDetails: showsDetails,
            isHovering: isHovering,
            rowBackground: { AnyView(rowBackground) },
            rowBorder: { AnyView(rowBorder) },
            hoverBackground: hoverBackground
        ))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var parameterButton: some View {
        AppIconButton(
            systemImage: "slider.horizontal.3",
            tint: isParametersPresented ? theme.textPrimary : theme.textSecondary,
            size: .compact,
            isActive: isParametersPresented
        ) {
            toggleParameterPopover()
        }
        .help(LumiPluginLocalization.string("调用参数", bundle: .module))
        .popover(isPresented: popoverBinding(selection: $parameterPopoverToolCallID), arrowEdge: .bottom) {
            ToolDetailPopoverView(
                title: "调用参数",
                systemImage: "slider.horizontal.3",
                trailingTitle: toolCall.name
            ) {
                ToolCallArgumentsView(toolCall: toolCall)
            }
        }
    }

    @ViewBuilder
    private var resultButton: some View {
        AppIconButton(
            systemImage: "doc.text.magnifyingglass",
            tint: isResultsPresented ? theme.textPrimary : theme.textSecondary,
            size: .compact,
            isActive: isResultsPresented
        ) {
            toggleResultPopover()
        }
        .help(LumiPluginLocalization.string("调用结果", bundle: .module))
        .popover(isPresented: popoverBinding(selection: $resultPopoverToolCallID), arrowEdge: .bottom) {
            // 结果按钮本身不持有数据:打开时先显示 loading,再去 kernel 查询该工具调用结果,
            // 查到后再渲染。
            ToolCallResultLazyPopover(
                kernel: kernel,
                toolCallID: toolCall.id,
                fallbackResult: toolCall.result
            )
        }
    }

    /// 仅悬停时出现的一层极淡底色,提示该行可交互;默认透明以融入正文。
    /// 仅用于 V1(inline)。
    private var hoverBackground: Color {
        guard isHovering else { return .clear }
        return visualState.isFailure ? theme.error.opacity(0.10) : theme.textSecondary.opacity(0.06)
    }

    /// V2/V3 的持续卡片背景。
    private var rowBackground: some View {
        Group {
            if isHovering {
                visualState.isFailure ? theme.error.opacity(0.12) : theme.textPrimary.opacity(0.08)
            } else {
                visualState.isFailure ? theme.error.opacity(0.08) : theme.textSecondary.opacity(0.06)
            }
        }
    }

    /// V2/V3 的持续卡片描边。
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
                visualState.isFailure
                    ? theme.error.opacity(isHovering ? 0.45 : 0.28)
                    : isHovering ? theme.textPrimary.opacity(0.12) : theme.textTertiary.opacity(0.06),
                lineWidth: 1
            )
    }

    private func toggleParameterPopover() {
        parameterPopoverToolCallID = isParametersPresented ? nil : toolCall.id
    }

    private func toggleResultPopover() {
        resultPopoverToolCallID = isResultsPresented ? nil : toolCall.id
    }

    private func popoverBinding(selection: Binding<String?>) -> Binding<Bool> {
        Binding {
            selection.wrappedValue == toolCall.id
        } set: { isPresented in
            if !isPresented, selection.wrappedValue == toolCall.id {
                selection.wrappedValue = nil
            }
        }
    }
}

/// 工具调用行的容器样式,按 `showsDetails` 分流,确保 V1 的 inline 改动
/// 不会波及 V2/V3 的卡片外观。
private struct ToolCallRowContainerModifier: ViewModifier {
    let showsDetails: Bool
    let isHovering: Bool
    @ViewBuilder let rowBackground: () -> AnyView
    @ViewBuilder let rowBorder: () -> AnyView
    let hoverBackground: Color

    func body(content: Content) -> some View {
        if showsDetails {
            // V2/V3:持续可见的卡片。
            content
                .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                .background(rowBackground())
                .overlay(rowBorder())
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .scaleEffect(isHovering ? 1.01 : 1)
                .animation(.easeOut(duration: 0.12), value: isHovering)
        } else {
            // V1:inline,默认无背景/描边,仅悬停时一层极淡底色。
            content
                .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                .background(hoverBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.12), value: isHovering)
        }
    }
}

// MARK: - ToolDetailPopoverView

private struct ToolDetailPopoverView<Content: View>: View {
    @LumiTheme private var theme

    let title: String
    let systemImage: String
    var trailingTitle: String?
    var isError = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(isError ? theme.error : theme.textSecondary)

                Text(title)
                    .font(.appCallout)
                    .foregroundColor(isError ? theme.error : theme.textPrimary)

                Spacer(minLength: 12)

                if let trailingTitle {
                    Text(trailingTitle)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            content
        }
        .padding(12)
        .frame(width: 520)
        .frame(minHeight: 200)
        .appSurface(style: .popover, cornerRadius: 0, borderColor: theme.divider)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
    }
}

// MARK: - ToolCallArgumentsView

private struct ToolCallArgumentsView: View {
    let toolCall: LumiToolCall

    var body: some View {
        if let formattedArguments {
            ToolTextSectionView(content: formattedArguments)
        } else {
            EmptyToolSectionView(systemImage: "info.circle", text: "没有可显示的调用参数")
        }
    }

    private var formattedArguments: String? {
        MessageViewHelpers.formatToolCallArguments(toolCall.arguments)
    }
}

// MARK: - ToolCallResultView

private struct ToolCallResultView: View {
    let result: LumiToolResult?
    let isLoading: Bool
    let visualState: ToolCallResultVisualState

    var body: some View {
        if isLoading {
            LoadingToolSectionView()
        } else if let result {
            VStack(alignment: .leading, spacing: 8) {
                if visualState.isFailure {
                    ToolFailureNoticeView()
                }

                // 工具返回的图片附件(如截图/抓图工具),在文本之前以网格展示
                if !resultImageData.isEmpty {
                    AppImagePreviewGrid(imageDataList: resultImageData)
                }

                if result.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if resultImageData.isEmpty {
                        EmptyToolSectionView(
                            systemImage: "info.circle",
                            text: visualState.isFailure ? "没有错误详情" : "暂无工具输出"
                        )
                    }
                } else {
                    ToolTextSectionView(content: result.content, isError: visualState.isFailure)
                }
            }
        } else {
            EmptyToolSectionView(systemImage: "info.circle", text: "暂无工具输出")
        }
    }

    /// 把工具结果的图片附件解码为 `[Data]`,供 `AppImagePreviewGrid` 展示。
    private var resultImageData: [Data] {
        result?.imageAttachments.compactMap { Data(base64Encoded: $0.base64Data) } ?? []
    }
}

// MARK: - ToolCallResultLazyPopover

/// 结果按钮弹层:不在打开前持有数据。打开时先展示 loading,再去 kernel 查询该工具调用结果,
/// 查到后再渲染。
///
/// `fallbackResult` 仅用于在 kernel 查询返回 nil(如结果尚未持久化、store 不可用)时,
/// 复用行内已解析的结果作为兜底,避免空面板。
private struct ToolCallResultLazyPopover: View {
    let kernel: KernelLumi
    let toolCallID: String
    let fallbackResult: LumiToolResult?

    @State private var result: LumiToolResult?
    @State private var didLoad = false

    private var isLoading: Bool {
        !didLoad
    }

    private var visualState: ToolCallResultVisualState {
        ToolCallResultVisualState(result: result, isLoading: isLoading)
    }

    var body: some View {
        ToolDetailPopoverView(
            title: "调用结果",
            systemImage: visualState.systemImage,
            isError: visualState.isFailure
        ) {
            ToolCallResultView(
                result: result,
                isLoading: isLoading,
                visualState: visualState
            )
        }
        .task {
            guard !didLoad else { return }
            let resolved = await kernel.toolManager?.toolCallResult(for: toolCallID)
            result = resolved ?? fallbackResult
            didLoad = true
        }
    }
}

