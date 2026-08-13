import Combine
import KernelLumi
import LumiUI
import SwiftUI
import UniformTypeIdentifiers

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

    /// 控制「添加项目」文件夹选择器的显隐。
    @State private var isImporterPresented = false

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
    private var promptSuggestions: [LumiPromptSuggestion] {
        kernel.promptSuggestions?.allPromptSuggestions ?? []
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            titleView

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
    }

    /// 将标题模板按 `%@` 拆分为前缀/后缀，项目名作为中间的可交互元素。
    /// 各语言翻译均含且仅含一个 `%@`，按其拆分即可得到正确的本地化前后缀。
    private var titleSegments: (prefix: String, suffix: String) {
        let template = LumiPluginLocalization.string("How can I help with %@?", bundle: .module)
        let parts = template.components(separatedBy: "%@")
        return (prefix: parts.first ?? "", suffix: parts.count > 1 ? parts[1] : "")
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

    /// 标题下方的提示词芯片：点击把提示词写入输入框并聚焦，便于直接开始对话。
    private var promptChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(promptSuggestions) { suggestion in
                Button {
                    kernel.conversationInput?.text = suggestion.prompt
                    kernel.conversationInput?.isInputFocused = true
                } label: {
                    HStack(spacing: 6) {
                        if let image = suggestion.systemImage {
                            Image(systemName: image)
                        }
                        Text(suggestion.title)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
            try? await projectService?.openProject(at: target.path)
        }
    }

    private func handleAddProject(_ result: Result<[URL], any Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let projectService = project
        Task {
            try? await projectService?.openProject(at: url.path)
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

    @State private var apiKey = ""
    @State private var saveError: String?

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

    private let suggestions = [
        "解释这段代码", "帮我写一个脚本", "总结这篇内容", "制定一个执行计划"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasConfiguredKey ? "bubble.left.and.bubble.right" : "key.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.primary.opacity(0.75))

            Text(hasConfiguredKey ? "开始和 Lumi 对话" : "配置 API Key 开始聊天")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            if hasConfiguredKey {
                Text("选择一个示例，或直接在下方输入你的问题。")
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            kernel.conversationInput?.text = suggestion
                            kernel.conversationInput?.isInputFocused = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: 520)
            } else if let providerInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前 Provider：\(providerInfo.displayName)")
                        .font(.subheadline.weight(.semibold))
                    Text("聊天请求需要 API Key，请在设置中配置后再开始对话。")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    AppInputField("API Key", text: $apiKey, fieldType: .secure)
                    Button("保存 API Key") {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    if let saveError {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(theme.warning)
                    }
                    Link("打开 Provider 官网获取 API Key", destination: providerInfo.websiteURL)
                        .font(.caption)
                }
                .padding(16)
                .frame(maxWidth: 460, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(theme.divider, lineWidth: 1) }
            } else {
                Text("还没有可用的 AI Provider，请先在设置中启用一个 Provider。")
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
            providerManager?.selectProvider(id: type(of: provider).info.id)
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
