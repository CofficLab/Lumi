import KernelCore
import KitAgentTool
import KitLocalization
import KitMarkdown
import LumiUI
import os
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import SwiftUI

// MARK: - ToolCallRowsView

/// V1 (brief) 模式：纯文本 inline 样式，完全融入消息正文；
/// V2/V3 模式：带图标/背景/边框/按钮的卡片行。

/// 按消息 id 缓存"完全解析"的工具调用数组(锁保护,有界)。
///
/// 动机:`List` 惰性行滚出视口即被拆除,`ToolCallRowsView` 的
/// `@State resolvedToolCalls` 随之丢失;滚回时 `.task` 重新逐个
/// `await kernel.resolveProvider((any ToolManagerProviding).self).toolCallResult(for:)`。结果不可变,
/// 跨物化缓存后重物化只做一次字典命中。
/// 仅缓存全部结果到位的解析;命中时校验工具调用 id 序列与当前消息一致,
/// 不一致(消息被编辑等罕见情形)按未命中处理。
final class ToolCallResolutionCache: @unchecked Sendable {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-renderer", category: "ToolCallResolution")

    static let shared = ToolCallResolutionCache()

    private let limit = 512
    private let lock = NSLock()
    private var storage: [UUID: [MessageToolCall]] = [:]
    private var insertionOrder: [UUID] = []

    func resolvedCalls(messageID: UUID, toolCalls: [MessageToolCall]?) -> [MessageToolCall]? {
        guard let current = toolCalls, !current.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let cached = storage[messageID] else { return nil }
        let currentIDs = current.map(\.id)
        let cachedIDs = cached.map(\.id)
        guard currentIDs == cachedIDs else { return nil }
        return cached
    }

    func storeIfFullyResolved(messageID: UUID, toolCalls: [MessageToolCall]) {
        guard !toolCalls.isEmpty, toolCalls.allSatisfy({ $0.result != nil }) else { return }
        lock.lock()
        defer { lock.unlock() }
        if storage[messageID] == nil {
            insertionOrder.append(messageID)
        }
        storage[messageID] = toolCalls
        if insertionOrder.count > limit {
            let overflow = insertionOrder.count - limit
            for id in insertionOrder.prefix(overflow) {
                storage.removeValue(forKey: id)
            }
            insertionOrder.removeFirst(overflow)
        }
    }
}

struct ToolCallRowsView: View {
    let kernel: KernelCoreContainer
    let message: Message
    let verbosity: LumiResponseVerbosity

    @State private var parameterPopoverToolCallID: String?
    @State private var resultPopoverToolCallID: String?
    @State private var resolvedToolCalls: [MessageToolCall]?

    private var toolCalls: [MessageToolCall] {
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
            // 命中"完全解析"缓存:List 惰性行滚出视口被拆除后 @State 丢失,
            // 历史上每次滚回都重新逐个 await kernel 查询工具结果。
            if let cached = ToolCallResolutionCache.shared.resolvedCalls(
                messageID: message.id,
                toolCalls: message.toolCalls
            ) {
                if resolvedToolCalls != cached {
                    resolvedToolCalls = cached
                }
                return
            }
            await resolveResults()
        }
    }

    @MainActor
    private func resolveResults() async {
        guard let manager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            ToolCallResolutionCache.logger.error("Failed to resolve ToolManagerProviding from kernel")
            return
        }
        var resolved = message.toolCalls ?? []
        for index in resolved.indices where resolved[index].result == nil {
            if let raw = await manager.toolCallResult(for: resolved[index].id),
               let converted = MessageToolResult(toolCallResult: raw) {
                resolved[index].result = converted
            }
        }
        // 仅当全部工具调用都有结果时才写入缓存:进行中的回合结果尚未落定,
        // 缓存会把"暂时为 nil"钉死成永久过期。
        ToolCallResolutionCache.shared.storeIfFullyResolved(
            messageID: message.id,
            toolCalls: resolved
        )
        if resolvedToolCalls != resolved {
            resolvedToolCalls = resolved
        }
    }

    private var lumiCardRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toolCalls) { toolCall in
                toolCallRow(for: toolCall)
            }
        }
    }

    @ViewBuilder
    private func toolCallRow(for toolCall: MessageToolCall) -> some View {
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

    let kernel: KernelCoreContainer
    let message: Message
    let toolCall: MessageToolCall
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

    /// 注:不再在 body 内查询 `ToolCallRowRendererRegistry` —— 两个构造方
    /// (`ToolCallRowsView` / `CollapsibleToolStepGroup`)都已先行查找并在命中时
    /// 自行渲染自定义行;这里的二次查找每次 body 求值(含 hover 与滚动
    /// 重物化)都白跑一遍 canRender 匹配链。注册表在插件加载期填充,不存在
    /// 运行中动态注册后依赖行重求值生效的场景。
    var body: some View {
        defaultToolCallRow
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
            rowBackground: rowBackground,
            rowBorder: rowBorder,
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
                trailingTitle: toolCall.name,
                minHeight: 0
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
///
/// 背景/描边以泛型视图值传入(历史上是返回 `AnyView` 的闭包,每次 body
/// 求值分配两个闭包 + 类型擦除包装)。
private struct ToolCallRowContainerModifier<Background: View, Border: View>: ViewModifier {
    let showsDetails: Bool
    let isHovering: Bool
    let rowBackground: Background
    let rowBorder: Border
    let hoverBackground: Color

    func body(content: Content) -> some View {
        if showsDetails {
            // V2/V3:持续可见的卡片。
            content
                .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                .background(rowBackground)
                .overlay(rowBorder)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    var minHeight: CGFloat = 200
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
        .frame(minHeight: minHeight)
        .appSurface(style: .popover, cornerRadius: 0, borderColor: theme.divider)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
    }
}

// MARK: - ToolCallArgumentsView

private struct ToolCallArgumentsView: View {
    let toolCall: MessageToolCall

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
    let result: MessageToolResult?
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
        result?.imageAttachments.compactMap { Data(base64Encoded: $0.data) } ?? []
    }
}

// MARK: - ToolCallResultLazyPopover

/// 结果按钮弹层:不在打开前持有数据。打开时先展示 loading,再去 kernel 查询该工具调用结果,
/// 查到后再渲染。
///
/// `fallbackResult` 仅用于在 kernel 查询返回 nil(如结果尚未持久化、store 不可用)时,
/// 复用行内已解析的结果作为兜底,避免空面板。
private struct ToolCallResultLazyPopover: View {
    let kernel: KernelCoreContainer
    let toolCallID: String
    let fallbackResult: MessageToolResult?

    @State private var result: MessageToolResult?
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
            let resolved = await kernel.resolveProvider((any ToolManagerProviding).self)?.toolCallResult(for: toolCallID)
            result = resolved.flatMap(MessageToolResult.init(toolCallResult:)) ?? fallbackResult
            didLoad = true
        }
    }
}
