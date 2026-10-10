import LumiUI
import SwiftUI

struct ListView: View {
    @ObservedObject var viewModel: ProjectsViewModel
    @State private var searchText = ""
    let addProject: () -> Void

    private var filteredProjects: [ProjectEntry] {
        if searchText.isEmpty {
            return viewModel.projects
        }
        return viewModel.projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            AppSearchBar(text: $searchText, placeholder: LocalizedStringKey(pluginLocalization.string("Search")))

            AppButton(pluginLocalization.string("Add"), systemImage: "folder.badge.plus", size: .small) {
                addProject()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var list: some View {
        if filteredProjects.isEmpty {
            if viewModel.projects.isEmpty {
                // 列表为空：引导添加项目（项目是可选功能，无项目时聊天仍可正常使用）
                AppEmptyState(
                    icon: "folder.badge.plus",
                    title: pluginLocalization.string("No Projects"),
                    description: pluginLocalization.string("Adding a project gives the agent file context. This is optional — chat works without one."),
                    actionTitle: pluginLocalization.string("Add Project"),
                    action: addProject
                )
                .frame(maxWidth: .infinity, minHeight: 126)
            } else {
                // 仅为搜索无匹配
                AppEmptyState(
                    icon: "magnifyingglass",
                    title: pluginLocalization.string("No Projects")
                )
                .frame(maxWidth: .infinity, minHeight: 126)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredProjects) { project in
                        RowView(
                            project: project,
                            isSelected: viewModel.currentProject?.path == project.path,
                            select: { viewModel.select(project) },
                            remove: { viewModel.remove(project) }
                        )
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
        }
    }
}
