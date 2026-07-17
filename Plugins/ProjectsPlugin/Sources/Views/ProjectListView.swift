import LumiUI
import SwiftUI
import LumiCoreKit

struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectsViewModel
    @State private var searchText = ""
    @Binding var isImporterPresented: Bool

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
            AppSearchBar(text: $searchText, placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search", bundle: .module)))

            AppButton(LumiPluginLocalization.string("Add", bundle: .module), systemImage: "folder.badge.plus", size: .small) {
                isImporterPresented = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var list: some View {
        if filteredProjects.isEmpty {
            AppEmptyState(icon: "folder.badge.plus", title: LumiPluginLocalization.string("No Projects", bundle: .module))
            .frame(maxWidth: .infinity, minHeight: 126)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredProjects) { project in
                        ProjectRowView(
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
