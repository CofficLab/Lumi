import KernelLumi
import LumiUI
import SwiftUI

/// Title toolbar 弹出的 popover 内容
///
/// 顶部一个 segmented Picker 充当 Tab:
/// - "All Projects":所有项目的对话
/// - "Current Project":当前项目的对话
///
/// 「Current Project」分段仅在「全库对话来自 ≥2 个项目」且「当前项目有对话」时才展示；
/// 否则该分段连同分段栏一并隐藏，只保留 "All Projects"（单一项目时二者视图相同，入口冗余）。
///
/// 切换 Tab 时通过 `if` 分支保留两个 `ListView` 的视图身份,
/// 让各自的滚动位置、分页状态和加载任务互不干扰。
struct ToolbarPopoverContent: View {
    @ObservedObject private var kernel: KernelLumi
    let attentionStore: ConversationAttentionStore
    @ObservedObject var sortStabilizer: ConversationSortStabilizer

    enum Scope: Hashable {
        case allProjects
        case currentProject
    }

    @State private var selectedScope: Scope = .allProjects
    /// 全库顶层对话是否来自 ≥2 个不同项目；决定按项目筛选是否有意义。
    /// 默认 false（先隐藏），异步查得后再决定，避免短暂展示冗余入口。
    @State private var hasMultipleProjects = false
    /// 当前项目的对话数是否 >0。
    /// 默认 false（先隐藏），异步查得数量后再决定，避免短暂展示一个空入口。
    @State private var currentProjectHasConversations = false

    init(kernel: KernelLumi,
         attentionStore: ConversationAttentionStore,
         sortStabilizer: ConversationSortStabilizer) {
        self._kernel = ObservedObject(wrappedValue: kernel)
        self.attentionStore = attentionStore
        self._sortStabilizer = ObservedObject(wrappedValue: sortStabilizer)
    }

    /// 当前项目路径；`nil` 表示未选中项目。
    private var currentProjectPath: String? {
        kernel.project?.currentProject?.path
    }

    /// 当前选中的项目名；用于分段标题。
    private var currentProjectName: String? {
        kernel.project?.currentProject?.name
            ?? currentProjectPath
    }

    /// 是否展示 "Current Project" 分段：已选中项目、全库 ≥2 个项目、且当前项目有对话。
    private var showsCurrentProjectScope: Bool {
        currentProjectPath != nil && hasMultipleProjects && currentProjectHasConversations
    }

    var body: some View {
        VStack(spacing: 0) {
            // 仅当「当前项目」分段可见时才渲染分段栏，否则只剩 "All Projects"，
            // 单一分段无需展示 Picker（与 rail 标签条「>1 个 tab 才显示」一致）。
            if showsCurrentProjectScope {
                tabBar
                Divider()
            }
            content
        }
        .frame(width: 300, height: 480)
        .task(id: currentProjectPath) {
            await refreshProjectScopeVisibility()
        }
        .onLumiConversationsDidChange {
            Task { await refreshProjectScopeVisibility() }
        }
        .onChange(of: showsCurrentProjectScope) { _, visible in
            // 「当前项目」分段消失时，若选中态残留在其上则回退到 "All Projects"。
            if !visible, selectedScope == .currentProject {
                selectedScope = .allProjects
            }
        }
    }

    /// 查询全库项目多样性 + 当前项目对话数，更新分段可见性相关状态。
    /// 仅在查询期间未发生项目切换时才写入结果，避免旧查询覆盖新状态。
    private func refreshProjectScopeVisibility() async {
        let path = currentProjectPath

        // 全库顶层对话是否来自 ≥2 个项目：单一项目时「全部对话」已等同该项目，
        // 「当前项目」分段冗余，直接隐藏，无需再查当前项目对话数。
        let projectCount = await kernel.conversations?.conversationProjectCount() ?? 0
        guard currentProjectPath == path else { return }
        hasMultipleProjects = projectCount >= 2

        guard let path, hasMultipleProjects else {
            currentProjectHasConversations = false
            return
        }
        let count = await kernel.conversations?.conversationCount(projectPath: path) ?? 0
        guard currentProjectPath == path else { return }
        currentProjectHasConversations = count > 0
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        Picker("", selection: pickerSelectionBinding) {
            Text(allProjectsTabTitle)
                .tag(Scope.allProjects)
            Text(currentProjectTabTitle)
                .tag(Scope.currentProject)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .disabled(currentProjectName == nil)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    /// 绑定:无项目时,即使 selectedScope 落在 .currentProject,也强制保持在 .allProjects,
    /// 避免 Picker 出现"已选中但 disabled"的卡死视觉。
    private var pickerSelectionBinding: Binding<Scope> {
        Binding(
            get: {
                if currentProjectName == nil, selectedScope == .currentProject {
                    return .allProjects
                }
                return selectedScope
            },
            set: { newValue in
                guard currentProjectName != nil || newValue == .allProjects else { return }
                selectedScope = newValue
            }
        )
    }

    private var allProjectsTabTitle: String {
        LumiPluginLocalization.string("All Projects", bundle: .module)
    }

    private var currentProjectTabTitle: String {
        if let name = currentProjectName {
            return name
        }
        return LumiPluginLocalization.string("Current Project", bundle: .module)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let conversationManager = kernel.conversationManager {
            if showsCurrentProjectScope, selectedScope == .currentProject {
                ListView(
                    kernel: kernel,
                    conversationManager: conversationManager,
                    attentionStore: attentionStore,
                    sortStabilizer: sortStabilizer,
                    projectPath: currentProjectPath
                )
                // 固定 .id,确保两个 Tab 切换时 ListView 身份稳定,
                // 各自的滚动/分页/加载任务互不重置。
                .id(Scope.currentProject)
            } else {
                ListView(
                    kernel: kernel,
                    conversationManager: conversationManager,
                    attentionStore: attentionStore,
                    sortStabilizer: sortStabilizer
                )
                .id(Scope.allProjects)
            }
        } else {
            ListErrorView(reason: "Conversation store service is not available")
        }
    }
}