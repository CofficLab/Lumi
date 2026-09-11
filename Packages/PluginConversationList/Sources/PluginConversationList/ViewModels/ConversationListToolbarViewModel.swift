import Combine
import Foundation
import ProviderChatSection
import ProviderConversation

/// 工具栏会话列表按钮 + Popover 唯一的数据来源与交互入口。
///
/// 聊天区可见性、全库对话存在性、项目分段可见性与选中分段全部收敛到这里；
/// 外部会话/聊天区事件由本 VM 内部订阅，View 不再创建任何外部 Observer。
@MainActor
final class ConversationListToolbarViewModel: ObservableObject {
    enum Scope: Hashable {
        case allProjects
        case currentProject
    }

    @Published private(set) var isChatSectionVisible = true
    @Published private(set) var hasAnyConversations = true
    @Published private(set) var hasMultipleProjects = false
    @Published private(set) var currentProjectHasConversations = false
    @Published var selectedScope: Scope = .allProjects
    @Published private(set) var contextRevision = 0

    private let context: ConversationListContext
    private var chatObserverHandle: (any ChatSectionProvidingObserverHandle)?
    private var contextObserverHandle: (any ConversationListContext.ObserverHandle)?
    private var pendingProjectRefresh: Task<Void, Never>?

    init(context: ConversationListContext) {
        self.context = context
        isChatSectionVisible = context.chat?.isVisible ?? true

        chatObserverHandle = context.chat?.addObserver { [weak self] event in
            if case let .visibilityChanged(isVisible) = event {
                self?.isChatSectionVisible = isVisible
            }
        }
        contextObserverHandle = context.addObserver { [weak self] event in
            if case .conversationsChanged = event {
                self?.contextRevision &+= 1
            }
        }
    }

    /// 插件卸载时调用，释放外部观察订阅。
    func cancel() {
        chatObserverHandle?.cancel()
        chatObserverHandle = nil
        contextObserverHandle?.cancel()
        contextObserverHandle = nil
        pendingProjectRefresh?.cancel()
        pendingProjectRefresh = nil
    }

    // MARK: - Derived

    var currentProjectPath: String? {
        context.currentProjectPath
    }

    var currentProjectName: String? {
        context.currentProjectName
    }

    /// 是否展示 "当前项目" 分段：已选中项目、全库 ≥2 个项目、且当前项目有对话。
    var showsCurrentProjectScope: Bool {
        currentProjectPath != nil && hasMultipleProjects && currentProjectHasConversations
    }

    var pickerSelection: Scope {
        get {
            if currentProjectName == nil, selectedScope == .currentProject {
                return .allProjects
            }
            return selectedScope
        }
        set {
            guard currentProjectName != nil || newValue == .allProjects else { return }
            selectedScope = newValue
            // 「当前项目」分段消失时，若选中态残留在其上则回退到 "所有项目"。
            if newValue == .currentProject, !showsCurrentProjectScope {
                selectedScope = .allProjects
            }
        }
    }

    var currentProjectTabTitle: String {
        if let name = currentProjectName {
            return name
        }
        return "当前项目"
    }

    // MARK: - 数据加载

    /// 查询全库顶层对话总数，据此决定按钮是否值得展示。
    func refreshConversationPresence() async {
        let count = await context.conversations.conversationCount(projectPath: nil)
        hasAnyConversations = count > 0
    }

    /// 查询全库项目多样性 + 当前项目对话数，更新分段可见性相关状态。
    func refreshProjectScopeVisibility() async {
        let path = currentProjectPath

        // 全库顶层对话是否来自 ≥2 个项目：单一项目时「全部对话」已等同该项目，
        // 「当前项目」分段冗余，直接隐藏，无需再查当前项目对话数。
        let projectCount = await context.conversations.conversationProjectCount()
        guard currentProjectPath == path else { return }
        hasMultipleProjects = projectCount >= 2

        guard let path, hasMultipleProjects else {
            currentProjectHasConversations = false
            if selectedScope == .currentProject {
                selectedScope = .allProjects
            }
            return
        }
        let count = await context.conversations.conversationCount(projectPath: path)
        guard currentProjectPath == path else { return }
        currentProjectHasConversations = count > 0
        if !showsCurrentProjectScope, selectedScope == .currentProject {
            selectedScope = .allProjects
        }
    }
}
