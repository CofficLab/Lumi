import Combine
import KernelLumi
import LumiUI
import SwiftUI
import UniformTypeIdentifiers
import os

/// 空态点击提示词的统一处理：
/// 1. 若来源插件未启用，先启用它（含同步重建贡献——确保其视图容器等已注册）；
/// 2. 执行提示词声明的动作（如激活来源插件的视图容器）；
/// 3. 发送消息。
///
/// `conversationID` 传 `nil`，由 `MessageSender` 选取当前选中会话；
/// 若当前未选中会话（`NoConversationSelectedView` 场景）则自动新建一个。
@MainActor
private func handlePromptSuggestionTap(
    _ suggestion: LumiPromptSuggestion,
    kernel: KernelLumi
) {
    let pluginID = suggestion.pluginID
    let needsEnable = suggestion.requiresEnable
    let prompt = suggestion.prompt
    let action = suggestion.action
    let control = kernel.pluginControl
    let sender = kernel.messageSender
    let workspace = kernel.workspace
    Task { @MainActor in
        if needsEnable, let pluginID, let control {
            if await control.enablePlugin(id: pluginID) {
                let pluginName = kernel.pluginManager.plugin(id: pluginID)?.name ?? pluginID
                kernel.toast?.show(
                    LumiPluginLocalization.string("Plugin Enabled", bundle: .module),
                    detail: String(
                        format: LumiPluginLocalization.string(
                            "%@ is now enabled.",
                            bundle: .module
                        ),
                        pluginName
                    ),
                    style: .success
                )
            }
        }
        // 动作在启用之后执行：禁用插件的视图容器要等重建后才注册。
        performPromptAction(action, workspace: workspace)
        try? await sender?.sendMessage(prompt, conversationID: nil)
    }
}

/// 执行提示词声明的动作（声明式，由内核能力统一落地，无需回到插件代码）。
@MainActor
private func performPromptAction(_ action: LumiPromptAction?, workspace: (any WorkspaceProviding)?) {
    guard let action else { return }
    switch action {
    case .activateViewContainer(let containerID):
        workspace?.activateContainer(id: containerID)
    case .activateRailTab(let railTabID, let containerID):
        // 先激活容器（确保其 rail 可见），再定位到指定 tab。
        workspace?.activateContainer(id: containerID)
        workspace?.presentRailTab(id: railTabID, for: containerID)
    }
}

/// 空态提示词的主题化胶囊芯片。
///
/// 镜像 `LumiUI.AppTag` 的强调风格（主题色玻璃底 + 悬停放大/高亮），
/// 支持前置图标，用于替换空态里观感较「原始」的原生 `.bordered` 按钮。
private struct PromptSuggestionChip: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference

    private let title: String
    private let systemImage: String?

    @State private var isHovered = false

    init(title: String, systemImage: String?) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
            }
            Text(title)
                .font(.appCaption)
                .lineLimit(1)
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(isHovered ? theme.primary.opacity(0.22) : theme.primary.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    isHovered ? theme.primary.opacity(0.40) : theme.primary.opacity(0.22),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered && motionPreference.allowsMotion ? LumiMotion.hoverScale : 1.0)
        .shadow(color: theme.primary.opacity(isHovered ? 0.20 : 0), radius: isHovered ? 8 : 0, y: isHovered ? 3 : 0)
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHovered)
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovered = hovering
            }
        }
    }
}

/// 提示词胶囊按钮：点击发送该提示词（必要时先启用来源插件、执行声明动作）。
private struct PromptSuggestionButton: View {
    private let suggestion: LumiPromptSuggestion
    private let kernel: KernelLumi

    init(_ suggestion: LumiPromptSuggestion, kernel: KernelLumi) {
        self.suggestion = suggestion
        self.kernel = kernel
    }

    var body: some View {
        Button {
            handlePromptSuggestionTap(suggestion, kernel: kernel)
        } label: {
            PromptSuggestionChip(
                title: suggestion.title,
                systemImage: suggestion.systemImage
            )
        }
        .buttonStyle(.plain)
    }
}

/// 未选择对话时的占位视图，围绕当前项目引导用户开始提问。
///
/// 标题中的项目名是一个可点击的下拉菜单：点击可切换到其它项目，
/// 或通过「添加项目…」选择一个新目录（由内核 `openProject(at:)` 统一处理，
/// 不在列表中的路径会被自动追加并切换）。
struct NoConversationSelectedView: View {
    @LumiTheme private var theme
    let kernel: KernelLumi
    @StateObject private var projectObserver: NoConversationProjectObserver
    @StateObject private var promptObserver: PromptSuggestionsObserver

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.message-list.no-conversation"
    )

    /// 控制「添加项目」文件夹选择器的显隐。
    @State private var isImporterPresented = false

    /// 项目切换/添加失败时的错误信息，非 nil 时弹出提示。
    @State private var errorMessage: String?

    init(kernel: KernelLumi) {
        self.kernel = kernel
        _projectObserver = StateObject(
            wrappedValue: NoConversationProjectObserver(project: kernel.project)
        )
        _promptObserver = StateObject(
            wrappedValue: PromptSuggestionsObserver(service: kernel.promptSuggestions)
        )
    }

    private var project: (any ProjectProviding)? { projectObserver.project }

    private var currentProject: ProjectInfo? { project?.currentProject }

    private var projects: [ProjectInfo] { project?.projects ?? [] }

    private var projectName: String {
        currentProject?.name
            ?? LumiPluginLocalization.string("Current Project", bundle: .module)
    }

    private var titleFont: Font { .system(size: 18, weight: .semibold) }

    /// 内核聚合后的全部提示词（来自各启用插件，按 order 排序）。
    /// 无当前项目时过滤掉声明了 `requiresProject` 的提示词（它们依赖项目上下文）。
    private var promptSuggestions: [LumiPromptSuggestion] {
        let all = kernel.promptSuggestions?.allPromptSuggestions ?? []
        guard currentProject != nil else {
            return all.filter { !$0.requiresProject }
        }
        return all
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            if projects.isEmpty {
                // 无任何项目：项目可选，不显示嵌入项目菜单的标题（避免出现
                // 「关于当前项目…」这类无指代对象的病句），改用通用问候语
                // + 「添加项目」按钮（位于提示词上方）。
                noProjectTitleView
                addProjectButton
            } else {
                titleView
            }

            if !promptSuggestions.isEmpty {
                promptChips
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleAddProject(result)
        }
        .alert(
            LumiPluginLocalization.string("Failed to Open Project", bundle: .module),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button(LumiPluginLocalization.string("OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// 将标题模板按 `%@` 拆分为前缀/后缀，项目名作为中间的可交互元素。
    /// 各语言翻译均含且仅含一个 `%@`，按其拆分即可得到正确的本地化前后缀。
    private var titleSegments: (prefix: String, suffix: String) {
        let template = LumiPluginLocalization.string("How can I help with %@?", bundle: .module)
        let parts = template.components(separatedBy: "%@")
        return (prefix: parts.first ?? "", suffix: parts.count > 1 ? parts[1] : "")
    }

    /// 无项目时的通用问候标题（不含可交互元素）。
    private var noProjectTitleView: some View {
        Text(LumiPluginLocalization.string("How can I help you today?", bundle: .module))
            .font(titleFont)
            .foregroundColor(theme.textPrimary)
            .multilineTextAlignment(.center)
    }

    /// 无项目时的「添加项目」按钮（位于提示词上方）：点击打开文件夹选择器。
    private var addProjectButton: some View {
        AppButton(
            LumiPluginLocalization.string("Add Project…", bundle: .module),
            systemImage: "folder.badge.plus",
            style: .secondary,
            size: .small
        ) {
            isImporterPresented = true
        }
    }

    /// 标题：前缀 + 项目名下拉菜单 + 后缀，仅项目名是可交互元素。
    private var titleView: some View {
        let segments = titleSegments
        return HStack(spacing: 0) {
            Text(segments.prefix)
                .font(titleFont)
                .foregroundColor(theme.textPrimary)

            projectMenu
                .font(titleFont)

            Text(segments.suffix)
                .font(titleFont)
                .foregroundColor(theme.textPrimary)
        }
        .multilineTextAlignment(.center)
    }

    /// 标题下方的提示词芯片：点击直接发送该提示词（新建对话）；若来源插件未启用，
    /// 会先启用它。带 `+` 徽标的芯片表示其插件当前未启用。
    private var promptChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(promptSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                PromptSuggestionButton(suggestion, kernel: kernel)
                    .landingAppear(delay: Double(index) * 0.04)
            }
        }
        .frame(maxWidth: 480)
    }

    /// 项目名下拉菜单：列出全部项目（当前项打勾）可切换，并提供「添加项目…」。
    private var projectMenu: some View {
        Menu {
            ForEach(projects, id: \.path) { project in
                let isCurrent = project.path == currentProject?.path
                Button {
                    switchToProject(project)
                } label: {
                    if isCurrent {
                        Label(project.name, systemImage: "checkmark")
                    } else {
                        Text(project.name)
                    }
                }
            }

            Divider()

            Button {
                isImporterPresented = true
            } label: {
                Label(
                    LumiPluginLocalization.string("Add Project…", bundle: .module),
                    systemImage: "plus"
                )
            }
        } label: {
            // 仅显示项目名：下拉箭头由 Menu 控件自身提供，不再额外叠加图标。
            Text(projectName)
                .foregroundColor(theme.primary)
                .fixedSize()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func switchToProject(_ target: ProjectInfo) {
        let projectService = project
        Task {
            do {
                try await projectService?.openProject(at: target.path)
            } catch {
                Self.logger.error("📂 切换项目失败 \(target.path): \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleAddProject(_ result: Result<[URL], any Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let projectService = project
        Task {
            do {
                try await projectService?.openProject(at: url.path)
            } catch {
                Self.logger.error("📂 添加项目失败 \(url.path): \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// 将 `ProjectProviding` 的更新桥接给 SwiftUI，同时避免直接观察协议存在类型。
@MainActor
private final class NoConversationProjectObserver: ObservableObject {
    let project: (any ProjectProviding)?
    private var cancellable: AnyCancellable?

    init(project: (any ProjectProviding)?) {
        self.project = project
        cancellable = project?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

/// 将 `PromptSuggestionProviding` 的更新桥接给 SwiftUI（插件启停时提示词列表变化）。
@MainActor
private final class PromptSuggestionsObserver: ObservableObject {
    let service: (any PromptSuggestionProviding)?
    private var cancellable: AnyCancellable?

    init(service: (any PromptSuggestionProviding)?) {
        self.service = service
        cancellable = service?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

/// Empty state view when the conversation has no messages.
struct MessageEmptyStateView: View {
    @LumiTheme private var theme
    let kernel: KernelLumi
    @StateObject private var promptObserver: PromptSuggestionsObserver

    @State private var apiKey = ""
    @State private var saveError: String?

    init(kernel: KernelLumi) {
        self.kernel = kernel
        _promptObserver = StateObject(
            wrappedValue: PromptSuggestionsObserver(service: kernel.promptSuggestions)
        )
    }

    private var providerManager: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var provider: (any LumiLLMProvider)? {
        guard let manager = providerManager else { return nil }
        if let selected = manager.selectedProviderID,
           let provider = manager.llmProvider(id: selected) {
            return provider
        }
        return manager.allLLMProviders().first
    }

    private var providerInfo: LumiLLMProviderInfo? {
        provider.map { type(of: $0).info }
    }

    private var hasConfiguredKey: Bool {
        provider?.apiKeyDiagnostic() == .configured
    }

    /// 内核聚合后的全部提示词（来自各插件，按 order 排序）。
    private var promptSuggestions: [LumiPromptSuggestion] {
        kernel.promptSuggestions?.allPromptSuggestions ?? []
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasConfiguredKey ? "bubble.left.and.bubble.right" : "key.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.primary.opacity(0.75))

            Text(hasConfiguredKey
                 ? LumiPluginLocalization.string("Start chatting with Lumi", bundle: .module)
                 : LumiPluginLocalization.string("Configure an API Key to start chatting", bundle: .module))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            if hasConfiguredKey {
                Text(LumiPluginLocalization.string("Pick an example, or type your question below.", bundle: .module))
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                if !promptSuggestions.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(promptSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                            PromptSuggestionButton(suggestion, kernel: kernel)
                                .landingAppear(delay: Double(index) * 0.04)
                        }
                    }
                    .frame(maxWidth: 520)
                }
            } else if let providerInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: LumiPluginLocalization.string("Current Provider: %@", bundle: .module), providerInfo.displayName))
                        .font(.subheadline.weight(.semibold))
                    Text(LumiPluginLocalization.string("Chat requests require an API Key. Configure one in Settings before you start.", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    AppInputField("API Key", text: $apiKey, fieldType: .secure)
                    Button(LumiPluginLocalization.string("Save API Key", bundle: .module)) {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    if let saveError {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(theme.warning)
                    }
                    Link(LumiPluginLocalization.string("Open the provider's website to get an API Key", bundle: .module), destination: providerInfo.websiteURL)
                        .font(.caption)
                }
                .padding(16)
                .frame(maxWidth: 460, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(theme.divider, lineWidth: 1) }
            } else {
                Text(LumiPluginLocalization.string("No AI Provider is available yet. Enable one in Settings first.", bundle: .module))
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            apiKey = provider?.getApiKey() ?? ""
        }
    }

    private func saveAPIKey() {
        guard let provider else { return }
        do {
            try provider.saveAPIKey(apiKey)
            providerManager?.selectProvider(id: provider.providerInfo.id)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > maxWidth {
                y += rowHeight + spacing; x = 0; rowHeight = 0
            }
            x += (x == 0 ? 0 : spacing) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(x, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Loading state view shown while the message list is fetching data.
///
/// Renders a single SF Symbol with a gentle breathing (opacity) animation
/// so the user perceives the app as "alive" without visual noise.
struct MessageLoadingView: View {
    @LumiTheme private var theme

    /// Drives the breathing opacity animation.
    @State private var isBreathing = false

    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right")
            .font(.largeTitle)
            .foregroundStyle(theme.textSecondary)
            .opacity(isBreathing ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear { isBreathing = true }
            .accessibilityLabel(Text(LumiPluginLocalization.string("Loading messages…", bundle: .module)))
    }
}

#Preview("Message loading") {
    MessageLoadingView()
        .frame(width: 480, height: 600)
}
