import LumiUI
import SwiftUI
import UniformTypeIdentifiers
import LumiCoreKit

struct ProjectsPopoverView: View {
    @ObservedObject var store: ProjectsStore
    @State private var isImporterPresented = false
    @State private var searchText = ""

    private var filteredProjects: [LumiProjectEntry] {
        if searchText.isEmpty {
            return store.projects
        }
        return store.projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            projectList
        }
        .frame(width: 320)
        .frame(minHeight: 220, maxHeight: 420)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
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
    private var projectList: some View {
        if filteredProjects.isEmpty {
            AppEmptyState(icon: "folder.badge.plus", title: LumiPluginLocalization.string("No Projects", bundle: .module))
            .frame(maxWidth: .infinity, minHeight: 126)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredProjects) { project in
                        ProjectRowView(
                            project: project,
                            isSelected: store.currentProject?.path == project.path,
                            select: { store.select(project) },
                            remove: { store.remove(project) }
                        )
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
        }
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        guard case let .success(urls) = result,
              let url = urls.first
        else {
            return
        }

        store.addProject(url: url)
    }
}
