import Foundation
import LumiUI
import ProviderChatSection
import ProviderProject
import ProviderPromptSuggestion
import SwiftUI
import UniformTypeIdentifiers

/// 「未选中任何会话」时的空态。
///
/// ## 标题为什么不再带项目名
///
/// 标题曾经是「对于「项目名」，我可以帮你做什么？」，项目名内嵌一个可展开的
/// 菜单用于切换项目。现在标题统一为「我可以帮你做什么？」，切换项目这件事
/// 交给工具栏里那个控件——同一个动作不该在两个地方各做一遍，尤其空态里
/// 那个下拉藏在半句话中间，既不像控件也不像文字。
struct NoConversationSelectedView: View {
    @LumiTheme private var theme
    let services: MessageListEmptyServices
    /// 近 30 天的活动卡。跟着提示流排在下面，而不是停在窗口底部的底栏里。
    let activity: EmptyStateActivityViewModel?
    /// 项目上下文卡的数据源。没有项目时整个卡片不渲染。
    let projectContext: ProjectContextViewModel?
    @ObservedObject private var guideState: MessageListGuideState
    @State private var importingFolder = false
    @State private var projectError: String?

    init(
        services: MessageListEmptyServices,
        guideState: MessageListGuideState,
        activity: EmptyStateActivityViewModel? = nil,
        projectContext: ProjectContextViewModel? = nil
    ) {
        self.services = services
        self.activity = activity
        self.projectContext = projectContext
        _guideState = ObservedObject(wrappedValue: guideState)
    }

    /// 当前项目。没有项目时提示流按「无项目」口径过滤。
    private var project: ProjectInfo? { guideState.currentProject }
    private var suggestions: [PromptSuggestion] {
        visibleSuggestions(
            services.promptSuggestions?.allSuggestions ?? [],
            hasProject: project != nil,
            contextID: guideState.context?.id
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EmptyStateAtmosphere()

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        EmptyStateHeroIcon(systemImage: guideState.context?.systemImage ?? "square.and.pencil")
                            .padding(.bottom, 18)

                        // 标题固定为通用问句。具名上下文（插件工作台）仍保留自己的
                        // 标题——那不是「项目名」，而是用户正在用的功能入口。
                        if let context = guideState.context,
                           context.id != ChatContext.defaultChat.id {
                            Text(String(format: pluginLocalization.string("For 「%@」, what can I help you with?"), context.title))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                                .multilineTextAlignment(.center)
                            if let subtitle = context.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }
                        } else {
                            Text(pluginLocalization.string("How can I help you today?"))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                                .multilineTextAlignment(.center)
                        }

                        if !suggestions.isEmpty {
                            PromptSuggestionFlow(suggestions: suggestions, services: services) { importingFolder = true }
                                .padding(.top, 24)
                        }

                        // 项目卡紧跟在提示流下面：与活动卡同宽同族。
                        // 项目身份信息由项目卡承担，标题不再重复项目名。
                        if let projectContext, projectContext.hasProject {
                            ProjectContextCard(model: projectContext, services: services)
                                .padding(.top, 26)
                                .task {
                                    await projectContext.loadIfNeeded()
                                }
                        }

                        // 活动卡紧跟在提示流下面：同一列、同一条底色，
                        // 两者之间不再有任何分隔线。
                        if let activity {
                            ActivityCardSlot(model: activity)
                                .padding(.top, 26)
                        }
                    }
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity, minHeight: max(320, proxy.size.height - 24))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 36)
                    .offset(y: -min(24, proxy.size.height * 0.06))
                }
                .scrollIndicators(.hidden)
            }
            // 标识符挂在 ScrollView 的**内容**而非外层 GeometryReader 上：
            // GeometryReader 是布局容器、无自身语义，在其上设置 identifier
            // 只会让整页子树被合并成一个元素，屏幕阅读器将失去内部结构。
            .accessibilityIdentifier(MessageListEmptyAccessibility.noConversationSelectedID)
        }
        .onAppear {
            guideState.toolbarCoordinator.activate()
        }
        .onDisappear {
            guideState.toolbarCoordinator.deactivate()
        }
        .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { @MainActor in do { try await services.project?.openProject(at: url.path, reason: .userSelected) } catch { projectError = error.localizedDescription } }
        }
        .alert(pluginLocalization.string("Failed to Open Project"), isPresented: Binding(get: { projectError != nil }, set: { if !$0 { projectError = nil } })) {
            Button(pluginLocalization.string("OK"), role: .cancel) {}
        } message: { Text(projectError ?? "") }
    }
}
