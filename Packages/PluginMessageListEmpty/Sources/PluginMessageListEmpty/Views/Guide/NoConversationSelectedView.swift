import Foundation
import LumiUI
import ProviderChatSection
import ProviderProject
import ProviderPromptSuggestion
import SwiftUI
import UniformTypeIdentifiers

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
                        } else if let project {
                            projectTitle(project)
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
                        // 这里不重复「项目身份行」——本视图的标题里已经带着项目名
                        // （还带一个可切换的下拉），再说一遍路径是噪音。
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

    @ViewBuilder
    private func projectTitle(_ project: ProjectInfo) -> some View {
        HStack(spacing: 0) {
            Text(pluginLocalization.string("For 「"))
                .foregroundStyle(theme.textPrimary)
            Menu {
                ForEach(guideState.projects, id: \.path) { item in
                    Button(item.name) { Task { @MainActor in do { try await services.project?.openProject(at: item.path, reason: .userSelected) } catch { projectError = error.localizedDescription } } }
                }
                Divider()
                Button(pluginLocalization.string("Add Project…")) { importingFolder = true }
            } label: {
                Text(project.name).foregroundStyle(theme.primary).lineLimit(1).truncationMode(.middle)
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: true, vertical: false)
            Text(pluginLocalization.string("」, what can I help you with?"))
                .foregroundStyle(theme.textPrimary)
        }.font(.system(size: 18, weight: .semibold))
    }
}
