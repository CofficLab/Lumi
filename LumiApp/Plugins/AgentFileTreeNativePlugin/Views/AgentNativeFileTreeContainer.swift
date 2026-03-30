import SwiftUI
import MagicKit

/// 高性能文件树容器视图
struct AgentNativeFileTreeContainer: View {
    @EnvironmentObject var ProjectVM: ProjectVM

    /// 折叠状态
    @AppStorage("Sidebar_FileTree_Expanded") private var isExpanded: Bool = true
    @State private var isHovered: Bool = false
    @State private var expandedRelativePaths: Set<String> = []
    private let selectionStore = FileTreeSelectionStore()
    private let expansionStore = FileTreeExpansionStore()

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            if isExpanded {
                GlassDivider()

                // 文件树
                if self.ProjectVM.isProjectSelected {
                    FileTreeView(
                        rootURL: URL(fileURLWithPath: ProjectVM.currentProjectPath),
                        selectedFileURL: ProjectVM.selectedFileURL,
                        expandedRelativePaths: expandedRelativePaths,
                        onSelect: { url in
                            ProjectVM.selectFile(at: url)
                            persistSelectionIfNeeded(url)
                        },
                        onExpandedPathsChanged: { paths in
                            expandedRelativePaths = paths
                            persistExpandedPathsIfNeeded(paths)
                        }
                    )
                } else {
                    emptyView
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            restoreExpandedPathsIfNeeded()
            restoreSelectionIfNeeded()
        }
        .onChange(of: ProjectVM.currentProjectPath) { _, _ in
            restoreExpandedPathsIfNeeded()
            restoreSelectionIfNeeded()
        }
        .onChange(of: ProjectVM.selectedFileURL) { _, newURL in
            guard let url = newURL else { return }
            persistSelectionIfNeeded(url)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: 16, height: 16)

                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text(String(localized: "File Tree", table: "AgentNativeFileTree"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Spacer()
            }

            if !ProjectVM.currentProjectPath.isEmpty {
                Text(ProjectVM.currentProjectPath)
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.textSecondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(AppUI.Color.semantic.textSecondary.opacity(0.5))
            Text(String(localized: "No Project", table: "AgentNativeFileTree"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func restoreSelectionIfNeeded() {
        let projectPath = canonicalProjectPath()
        guard !projectPath.isEmpty else { return }

        // 当前已选中文件且仍属于当前项目时，不覆盖用户选择。
        if let selectedURL = ProjectVM.selectedFileURL, isFileInCurrentProject(selectedURL) {
            return
        }

        guard let savedPath = selectionStore.loadSelectionPath(forProjectPath: projectPath) else { return }
        let savedURL = URL(fileURLWithPath: savedPath).standardizedFileURL

        guard isFileInCurrentProject(savedURL) else {
            selectionStore.removeSelection(forProjectPath: projectPath)
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: savedURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            selectionStore.removeSelection(forProjectPath: projectPath)
            return
        }

        ProjectVM.selectFile(at: savedURL)
    }

    private func persistSelectionIfNeeded(_ url: URL) {
        guard isFileInCurrentProject(url) else { return }
        let projectPath = canonicalProjectPath()
        guard !projectPath.isEmpty else { return }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return }

        selectionStore.saveSelectionPath(url.standardizedFileURL.path, forProjectPath: projectPath)
    }

    private func isFileInCurrentProject(_ url: URL) -> Bool {
        let projectPath = canonicalProjectPath()
        guard !projectPath.isEmpty else { return false }

        let standardizedProjectPath = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        let standardizedFilePath = url.standardizedFileURL.path

        return standardizedFilePath == standardizedProjectPath || standardizedFilePath.hasPrefix(standardizedProjectPath + "/")
    }

    private func restoreExpandedPathsIfNeeded() {
        let projectPath = canonicalProjectPath()
        guard !projectPath.isEmpty else {
            expandedRelativePaths = []
            return
        }
        expandedRelativePaths = expansionStore.loadExpandedRelativePaths(forProjectPath: projectPath)
    }

    private func persistExpandedPathsIfNeeded(_ paths: Set<String>) {
        let projectPath = canonicalProjectPath()
        guard !projectPath.isEmpty else { return }
        expansionStore.saveExpandedRelativePaths(paths, forProjectPath: projectPath)
    }

    private func canonicalProjectPath() -> String {
        let path = ProjectVM.currentProjectPath
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

#Preview {
    AgentNativeFileTreeContainer()
        .inRootView()
        .frame(width: 250, height: 400)
}
