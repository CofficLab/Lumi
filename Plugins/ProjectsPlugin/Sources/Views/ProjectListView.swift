import LumiUI
import SwiftUI
import AppKit

struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectsViewModel
    @State private var searchText = ""
    @Binding var isImporterPresented: Bool
    @State private var errorAlertMessage: String?
    @State private var showErrorAlert = false

    private var filteredProjects: [ProjectEntry] {
        if searchText.isEmpty {
            return viewModel.projects
        }
        return viewModel.projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var projectsDirectory: URL {
        viewModel.store.settingsDirectory
    }

    private func openProjectsDirectory() {
        let url = projectsDirectory

        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            errorAlertMessage = "Failed to create directory: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }

        // Verify directory exists and is readable
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorAlertMessage = "Directory does not exist: \(url.path)"
            showErrorAlert = true
            return
        }

        let success = NSWorkspace.shared.open(url)
        if !success {
            errorAlertMessage = "Failed to open directory: \(url.path)"
            showErrorAlert = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorAlertMessage ?? "Unknown error")
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
            AppEmptyState(
                icon: "folder.badge.plus",
                title: LumiPluginLocalization.string("No Projects", bundle: .module),
                actionTitle: LumiPluginLocalization.string("Open Directory", bundle: .module),
                action: openProjectsDirectory
            )
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
