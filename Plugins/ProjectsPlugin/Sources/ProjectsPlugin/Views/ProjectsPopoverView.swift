import LumiUI
import SwiftUI
import UniformTypeIdentifiers

struct ProjectsPopoverView: View {
    @ObservedObject var store: ProjectsStore
    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            projectList
            Divider()
            footer
        }
        .frame(width: 320)
        .frame(minHeight: 220, maxHeight: 420)
        .appSurface(style: .popover, cornerRadius: 12, borderColor: Color.primary.opacity(0.08))
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
            Image(systemName: "folder")
                .font(.system(size: 14, weight: .semibold))

            Text("Projects")
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var projectList: some View {
        if store.projects.isEmpty {
            AppEmptyState(icon: "folder.badge.plus", title: "No Projects")
            .frame(maxWidth: .infinity, minHeight: 126)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.projects) { project in
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

    private var footer: some View {
        AppButton("Open Folder...", systemImage: "folder.badge.plus", style: .ghost, size: .small, fillsWidth: true) {
            isImporterPresented = true
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
