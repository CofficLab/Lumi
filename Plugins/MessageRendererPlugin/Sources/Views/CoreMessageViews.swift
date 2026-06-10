import AppKit
import AgentToolKit
import LumiCoreKit
import LumiUI
import MarkdownKit
import SwiftUI

struct CoreMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool
    @State private var didCopy = false

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            messageHeader
            
            switch message.role {
            case .user:
                userContent
            case .assistant:
                assistantContent
            case .tool:
                utilityContent(tint: theme.success)
            case .system:
                utilityContent(tint: theme.textSecondary)
            case .error:
                utilityContent(tint: theme.error)
            case .status:
                EmptyView()
            }

            if showRawMessage {
                rawMessageView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageHeader: some View {
        CompactMessageHeaderView {
            HStack(alignment: .center, spacing: 6) {
                ChatAvatarView(kind: avatarKind)
                AppIdentityRow(title: headerTitle, metadata: metadataItems)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                CopyMessageButton(content: copyContent, showFeedback: $didCopy)

                AppIdentityRow(
                    title: formatTimestamp(message.createdAt),
                    titleColor: theme.textSecondary
                )

                MessageInfoButton(message: message)
            }
        }
    }

    private var userContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.userImageData.isEmpty {
                AppImagePreviewGrid(imageDataList: message.userImageData)
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
        }
        .appMessageBubble(role: .user, isError: message.isError)
    }

    @ViewBuilder
    private var assistantContent: some View {
        CollapsibleAssistantContent(message: message, shouldHideAssistantBody: shouldHideAssistantBody)
    }

    @ViewBuilder
    private func utilityContent(tint: Color) -> some View {
        Group {
            if message.role == .tool {
                toolContent
            } else if message.role == .error {
                errorContent
            } else {
                plainContent
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(message.role == .system ? 0.07 : 0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private var toolContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: message.isError ? "exclamationmark.triangle.fill" : "doc.text.magnifyingglass")
                    .foregroundColor(message.isError ? theme.error : theme.success)
                Text(message.toolCallID.map { "Tool Result \($0)" } ?? "Tool Result")
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)
            }

            Text(message.content)
                .font(.appMonoCaption)
                .foregroundColor(theme.textPrimary)
                .textSelection(.enabled)
        }
    }

    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.content.isEmpty ? "Request failed." : message.content)
                .font(.appBody)
                .foregroundColor(theme.error)
                .textSelection(.enabled)

            if let detail = message.rawErrorDetail, !detail.isEmpty {
                Text(detail)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var plainContent: some View {
        Text(message.content)
            .font(.appBody)
            .foregroundColor(theme.textPrimary)
            .textSelection(.enabled)
            .lineSpacing(3)
    }

    private var rawMessageView: some View {
        Text(rawDescription)
            .font(.appMonoCaption)
            .foregroundColor(theme.textSecondary)
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface(style: .panel, cornerRadius: 8)
    }

    private var metadataItems: [String] {
        var items: [String] = []
        if let providerID = message.providerID, !providerID.isEmpty {
            items.append(providerID)
        }
        if let modelName = message.modelName, !modelName.isEmpty {
            items.append(formatModelName(modelName))
        }
        return items
    }

    private func formatTimestamp(_ date: Date) -> String {
        Self.timestampFormatter.string(from: date)
    }

    private func formatModelName(_ name: String) -> String {
        let parts = name.split(separator: "-")
        if parts.count > 2, let lastPart = parts.last, lastPart.allSatisfy({ $0.isNumber }) {
            return parts.dropLast().joined(separator: "-")
        }
        return name
    }

    private var avatarKind: ChatAvatarKind {
        switch message.role {
        case .user:
            .user
        case .assistant:
            .assistant
        case .tool:
            .tool
        case .system:
            .system
        case .error:
            .error
        case .status:
            .status
        }
    }

    private var headerTitle: String {
        switch message.role {
        case .user:
            userDisplayName
        case .assistant:
            "Lumi"
        case .tool:
            "Tool"
        case .system:
            "System"
        case .error:
            "Error"
        case .status:
            "Status"
        }
    }

    private var userDisplayName: String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? NSUserName() : fullName
    }

    private var copyContent: String {
        if message.content.isEmpty {
            rawDescription
        } else {
            message.content
        }
    }

    private var rawDescription: String {
        [
            "id: \(message.id.uuidString)",
            "role: \(message.role.rawValue)",
            "provider: \(message.providerID ?? "-")",
            "model: \(message.modelName ?? "-")",
            "renderKind: \(message.renderKind ?? "-")",
            "toolCallID: \(message.toolCallID ?? "-")",
            "rawError: \(message.rawErrorDetail ?? "-")",
            "metadata: \(message.metadata)",
        ].joined(separator: "\n")
    }

    private var shouldHideAssistantBody: Bool {
        guard message.role == .assistant,
              let toolCalls = message.toolCalls,
              !toolCalls.isEmpty
        else {
            return false
        }

        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            return false
        }

        let lines = trimmedContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first else {
            return false
        }

        let isToolSummary = firstLine.hasPrefix("正在执行 ") || firstLine.hasPrefix("Executing ")
        return isToolSummary && lines.count <= toolCalls.count + 1
    }
}

private struct CompactMessageHeaderView<Leading: View, Trailing: View>: View {
    @LumiTheme private var theme

    let leading: Leading
    let trailing: Trailing

    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovered = false

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            leading
            Spacer()
            trailing
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .appSurface(
            style: .custom(headerBackgroundColor),
            cornerRadius: 8,
            borderColor: theme.divider.opacity(isHovered ? 1.0 : 0.65)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovered = hovering
            }
        }
    }

    private var headerBackgroundColor: Color {
        isHovered
            ? theme.textSecondary.opacity(0.14)
            : theme.textSecondary.opacity(0.08)
    }
}

private struct ToolCallRowsView: View {
    let message: LumiChatMessage

    @State private var parameterPopoverToolCallID: String?
    @State private var resultPopoverToolCallID: String?

    private var toolCalls: [LumiToolCall] {
        message.toolCalls ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toolCalls) { toolCall in
                ToolCallRowView(
                    message: message,
                    toolCall: toolCall,
                    parameterPopoverToolCallID: $parameterPopoverToolCallID,
                    resultPopoverToolCallID: $resultPopoverToolCallID
                )
            }
        }
    }
}

private struct ToolCallRowView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let toolCall: LumiToolCall
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
                        assistantMessageId: message.id
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

                Text(toolCall.displayName ?? toolCall.name)
                    .font(.appCaption)
                    .foregroundColor(visualState.isFailure ? theme.error : theme.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let duration = toolCall.result?.duration {
                Text(formatDuration(duration))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }

            AppIconButton(
                systemImage: "slider.horizontal.3",
                tint: isParametersPresented ? theme.textPrimary : theme.textSecondary,
                size: .regular,
                isActive: isParametersPresented
            ) {
                toggleParameterPopover()
            }
            .help("调用参数")
            .popover(isPresented: popoverBinding(selection: $parameterPopoverToolCallID), arrowEdge: .bottom) {
                ToolDetailPopoverView(
                    title: "\(toolCall.name) · 调用参数",
                    systemImage: "slider.horizontal.3"
                ) {
                    ToolCallArgumentsView(toolCall: toolCall)
                }
            }

            AppIconButton(
                systemImage: visualState.systemImage,
                tint: isResultsPresented
                    ? theme.textPrimary
                    : visualState.isFailure ? theme.error : theme.textSecondary,
                size: .regular,
                isActive: isResultsPresented
            ) {
                toggleResultPopover()
            }
            .help("调用结果")
            .popover(isPresented: popoverBinding(selection: $resultPopoverToolCallID), arrowEdge: .bottom) {
                ToolDetailPopoverView(
                    title: "调用结果",
                    systemImage: visualState.systemImage,
                    isError: visualState.isFailure
                ) {
                    ToolCallResultView(
                        result: toolCall.result,
                        isLoading: isLoadingResult,
                        visualState: visualState
                    )
                }
            }
        }
        .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
        .background(rowBackground)
        .overlay(rowBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isHovering ? 1.01 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var rowBackground: some View {
        Group {
            if isHovering {
                visualState.isFailure ? theme.error.opacity(0.12) : Color.white.opacity(0.08)
            } else {
                visualState.isFailure ? theme.error.opacity(0.08) : theme.textSecondary.opacity(0.06)
            }
        }
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                visualState.isFailure
                    ? theme.error.opacity(isHovering ? 0.45 : 0.28)
                    : isHovering ? Color.white.opacity(0.12) : theme.textTertiary.opacity(0.06),
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int(duration * 1000))ms"
        }

        if duration < 60 {
            return String(format: "%.1fs", duration)
        }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

private struct ToolDetailPopoverView<Content: View>: View {
    @LumiTheme private var theme

    let title: String
    let systemImage: String
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
            }

            content
        }
        .padding(12)
        .frame(width: 520)
        .background(Material.regularMaterial)
    }
}

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
        guard !toolCall.arguments.isEmpty,
              toolCall.arguments != "{}",
              let data = toolCall.arguments.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }

        if let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        return toolCall.arguments
    }
}

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

                if result.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyToolSectionView(
                        systemImage: "info.circle",
                        text: visualState.isFailure ? "没有错误详情" : "暂无工具输出"
                    )
                } else {
                    ToolTextSectionView(content: result.content, isError: visualState.isFailure)
                }
            }
        } else {
            EmptyToolSectionView(systemImage: "info.circle", text: "暂无工具输出")
        }
    }
}

private struct LoadingToolSectionView: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("查询结果中...")
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

private struct ToolFailureNoticeView: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.error)

            Text("工具执行失败")
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.error)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

private struct ToolTextSectionView: View {
    @LumiTheme private var theme

    let content: String
    var isError = false

    var body: some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(content)
                    .font(.appMonoCaption)
                    .foregroundColor(isError ? theme.error : theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 360)
        }
    }
}

private struct EmptyToolSectionView: View {
    @LumiTheme private var theme

    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(theme.textSecondary)

            Text(text)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

private struct ToolSubtleCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            content
        }
    }
}

private extension View {
    func toolSubtleCard() -> some View {
        modifier(ToolSubtleCardModifier())
    }
}

struct TurnCompletedDividerView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage

    var body: some View {
        AppLabeledDivider(
            title: "结束",
            detail: message.createdAt.formatted(date: .omitted, time: .standard)
        )
        .padding(.vertical, 8)
    }
}

struct StatusMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CompactMessageHeaderView {
                HStack(alignment: .center, spacing: 6) {
                    ChatAvatarView(kind: .status)
                    AppIdentityRow(title: "Status")
                }
            } trailing: {
                HStack(alignment: .center, spacing: 12) {
                    AppIdentityRow(
                        title: Self.timestampFormatter.string(from: message.createdAt),
                        titleColor: theme.textSecondary
                    )

                    MessageInfoButton(message: message)
                }
            }

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.75)

                Text(message.content)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(4)
                    .textSelection(.enabled)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appMessageBubble(role: .status, isError: false)
        }
    }
}

private struct CollapsibleAssistantContent: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let shouldHideAssistantBody: Bool
    @State private var isCollapsed = true

    private let collapseLineLimit = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let thinking = message.metadata["thinkingContent"], !thinking.isEmpty {
                DisclosureGroup("Thinking") {
                    Text(thinking)
                        .font(.appMonoCaption)
                        .foregroundColor(theme.textSecondary)
                        .textSelection(.enabled)
                }
                .font(.appCaptionEmphasized)
            }

            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !shouldHideAssistantBody {
                let lines = message.content.components(separatedBy: .newlines)
                let shouldCollapse = lines.count > collapseLineLimit
                let rendered = shouldCollapse && isCollapsed
                    ? lines.prefix(collapseLineLimit).joined(separator: "\n") + "\n..."
                    : message.content

                MarkdownBlockRenderer(markdown: rendered)
                    .textSelection(.enabled)
                    .font(.appBody)

                if shouldCollapse {
                    Button(isCollapsed ? "Show more" : "Show less") {
                        isCollapsed.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.appCaption)
                    .foregroundColor(theme.primary)
                }
            }

            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                ToolCallRowsView(message: message)
                    .padding(.top, shouldHideAssistantBody ? 0 : 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum ToolCallResultVisualState: Equatable {
    case loading
    case failed
    case completed

    init(result: LumiToolResult?, isLoading: Bool) {
        if isLoading {
            self = .loading
        } else if result?.isError == true {
            self = .failed
        } else {
            self = .completed
        }
    }

    var systemImage: String {
        switch self {
        case .loading:
            "hourglass"
        case .failed:
            "exclamationmark.triangle.fill"
        case .completed:
            "doc.text.magnifyingglass"
        }
    }

    var isFailure: Bool {
        self == .failed
    }
}
