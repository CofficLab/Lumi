import LumiUI
import ProviderChatSection
import ProviderPromptSuggestion
import SwiftUI
import UniformTypeIdentifiers

struct MessageEmptyStateView: View {
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

    /// 空态标题。
    ///
    /// 统一为「我可以帮你做什么？」：项目名曾内嵌在标题里并带一个切换菜单，
    /// 但切换项目是工具栏控件的职责，空态里再放一份只会让标题读起来像半句话。
    private var emptyStateTitle: String {
        pluginLocalization.string("How can I help you today?")
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EmptyStateAtmosphere()

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        EmptyStateHeroIcon(systemImage: guideState.context?.systemImage ?? "bubble.left.and.bubble.right")
                            .padding(.bottom, 18)

                        Text(emptyStateTitle)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .multilineTextAlignment(.center)

                        // 副标题：有项目时让位给项目身份行，其余情况沿用原文案。
                        if let identity = projectContext?.identity {
                            ProjectIdentityLine(identity: identity)
                                .padding(.top, 8)
                        } else if let subtitle = guideState.context?.subtitle,
                                  guideState.context?.id != ChatContext.defaultChat.id {
                            Text(subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        } else {
                            Text(pluginLocalization.string("Pick an example, or type your question below."))
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }

                        let suggestions = visibleSuggestions(
                            services.promptSuggestions?.allSuggestions ?? [],
                            hasProject: services.project?.currentProject != nil,
                            contextID: guideState.context?.id
                        )
                        if !suggestions.isEmpty {
                            PromptSuggestionFlow(suggestions: suggestions, services: services) { importingFolder = true }
                                .padding(.top, 24)
                        }

                        // 项目卡紧跟在提示流下面：与活动卡同宽同族，
                        // 三块内容读起来是同一列，而不是三个控件。
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
            // 挂在内容而非外层 GeometryReader：后者是纯布局容器，
            // 在其上设置 identifier 会让整页子树被合并成一个元素。
            .accessibilityIdentifier(MessageListEmptyAccessibility.noMessagesID)
        }
        .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { @MainActor in
                do { try await services.project?.openProject(at: url.path, reason: .userSelected) }
                catch { projectError = error.localizedDescription }
            }
        }
        .alert(pluginLocalization.string("Failed to Open Project"), isPresented: Binding(get: { projectError != nil }, set: { if !$0 { projectError = nil } })) {
            Button(pluginLocalization.string("OK"), role: .cancel) {}
        } message: { Text(projectError ?? "") }
    }
}
