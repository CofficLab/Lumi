import LumiKernel
import LumiUI
import SwiftUI

/// Title toolbar 弹出的 popover 内容
///
/// 顶部一个 segmented Picker 充当 Tab:
/// - "All Projects":所有项目的对话
/// - "Current Project":当前项目的对话(未选中项目时禁用)
///
/// 切换 Tab 时通过 `if` 分支保留两个 `ListView` 的视图身份,
/// 让各自的滚动位置、分页状态和加载任务互不干扰。
struct ToolbarPopoverContent: View {
    let kernel: LumiKernel
    let attentionStore: ConversationAttentionStore

    enum Scope: Hashable {
        case allProjects
        case currentProject
    }

    @State private var selectedScope: Scope = .allProjects

    /// 当前选中的项目;`nil` 时禁用 "Current Project" Tab。
    private var currentProjectName: String? {
        kernel.project?.currentProject?.name
            ?? kernel.project?.currentProject?.path
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            content
        }
        .frame(width: 300, height: 480)
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
            switch selectedScope {
            case .allProjects:
                ListView(
                    kernel: kernel,
                    conversationManager: conversationManager,
                    attentionStore: attentionStore
                )
                // 固定 .id,确保两个 Tab 切换时 ListView 身份稳定,
                // 各自的滚动/分页/加载任务互不重置。
                .id(Scope.allProjects)
            case .currentProject:
                ListView(
                    kernel: kernel,
                    conversationManager: conversationManager,
                    attentionStore: attentionStore,
                    projectPath: kernel.project?.currentProject?.path
                )
                .id(Scope.currentProject)
            }
        } else {
            ListErrorView(reason: "Conversation store service is not available")
        }
    }
}