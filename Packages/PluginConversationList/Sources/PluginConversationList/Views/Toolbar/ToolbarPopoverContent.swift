import SwiftUI

/// Title toolbar 弹出的 popover 内容（复刻旧版 ConversationListPlugin.ToolbarPopoverContent）
///
/// 顶部一个 segmented Picker 充当 Tab:
/// - "所有项目"：所有项目的对话
/// - "当前项目"：当前项目的对话
///
/// 「当前项目」分段仅在「全库对话来自 ≥2 个项目」且「当前项目有对话」时才展示；
/// 否则该分段连同分段栏一并隐藏，只保留 "所有项目"（单一项目时二者视图相同，入口冗余）。
///
/// 切换 Tab 时通过 `if` 分支保留两个 `ListView` 的视图身份,
/// 让各自的滚动位置、分页状态和加载任务互不干扰。
///
/// View 只依赖 ViewModel，不创建外部 Observer。
struct ToolbarPopoverContent: View {
    @ObservedObject private var viewModel: ConversationListToolbarViewModel
    private let allProjectsViewModel: ConversationListViewModel
    private let currentProjectViewModel: ConversationListViewModel

    init(
        viewModel: ConversationListToolbarViewModel,
        allProjectsViewModel: ConversationListViewModel,
        currentProjectViewModel: ConversationListViewModel
    ) {
        self.viewModel = viewModel
        self.allProjectsViewModel = allProjectsViewModel
        self.currentProjectViewModel = currentProjectViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // 仅当「当前项目」分段可见时才渲染分段栏，否则只剩 "所有项目"，
            // 单一分段无需展示 Picker（与 rail 标签条「>1 个 tab 才显示」一致）。
            if viewModel.showsCurrentProjectScope {
                tabBar
                Divider()
            }
            content
        }
        .frame(width: 300)
        .frame(maxHeight: 360)
        .task(id: viewModel.currentProjectPath) {
            await viewModel.refreshProjectScopeVisibility()
        }
        .onChange(of: viewModel.contextRevision) { _, _ in
            Task { await viewModel.refreshProjectScopeVisibility() }
        }
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        Picker("", selection: pickerSelectionBinding) {
            Text("所有项目")
                .tag(ConversationListToolbarViewModel.Scope.allProjects)
            Text(viewModel.currentProjectTabTitle)
                .tag(ConversationListToolbarViewModel.Scope.currentProject)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .disabled(viewModel.currentProjectName == nil)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    /// 绑定:无项目时,即使 selectedScope 落在 .currentProject,也强制保持在 .allProjects,
    /// 避免 Picker 出现"已选中但 disabled"的卡死视觉。
    private var pickerSelectionBinding: Binding<ConversationListToolbarViewModel.Scope> {
        Binding(
            get: { viewModel.pickerSelection },
            set: { viewModel.pickerSelection = $0 }
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.showsCurrentProjectScope, viewModel.selectedScope == .currentProject {
            ListView(viewModel: currentProjectViewModel)
            // 固定 .id,确保两个 Tab 切换时 ListView 身份稳定,
            // 各自的滚动/分页/加载任务互不重置。
            .id(ConversationListToolbarViewModel.Scope.currentProject)
        } else {
            ListView(viewModel: allProjectsViewModel)
            .id(ConversationListToolbarViewModel.Scope.allProjects)
        }
    }
}
