import LumiUI
import LumiCoreKit
import SwiftUI

/// 最近项目侧边栏视图
public struct ProjectsSidebarView: View {
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var recentProjectsVM: AppProjectsVM
    @StateObject private var branchCache = GitBranchCache()
    @State private var isFileImporterPresented = false

    private let store = ProjectsStore()

    public var body: some View {
        VStack(spacing: 0) {
            // 最近项目列表
            if !recentProjects.isEmpty {
                recentProjectsList
            } else {
                emptyView
            }

            GlassDivider()

            tipsCard
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            refreshAllBranches()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            refreshAllBranches()
        }
        .onApplicationDidBecomeActive {
            refreshAllBranches()
        }
    }

    // MARK: - Recent Projects List

    private var recentProjectsList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(recentProjects) { project in
                    projectRow(project)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Project Row

    private func projectRow(_ project: Project) -> some View {
        let isSelected = projectVM.currentProjectPath == project.path
        let branchName = branchCache.branch(for: project.path)
        let hasBranch = branchName != nil && !branchName!.isEmpty

        return HStack(spacing: 8) {
            Image(systemName: isSelected ? "folder.fill" : "folder")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(project.name)
                        .font(.system(size: 12))
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        .lineLimit(1)

                    if hasBranch {
                        gitBranchBadge(branchName!)
                    }
                }

                Text(project.path)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            switchToProject(project)
        }
        .onDrag {
            // 传递纯文本路径字符串，与文件树的拖拽方式一致，
            // 拖到输入框时 EditorTextView 会自动识别绝对路径并插入
            NSItemProvider(object: project.path as NSString)
        } preview: {
            ProjectDragPreview(fileURL: URL(fileURLWithPath: project.path))
        }
    }

    // MARK: - Git Branch Badge

    /// Git 分支标签：紧凑的药丸样式，在项目名右侧显示
    private func gitBranchBadge(_ branch: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 7, weight: .semibold))

            Text(branch)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(Color(hex: "7C6FFF"))
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            Capsule()
                .fill(Color(hex: "7C6FFF").opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color(hex: "7C6FFF").opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "No Projects", table: "Projects"))
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Computed Properties

    private var recentProjects: [Project] {
        recentProjectsVM.recentProjects
    }

    private var tipsCard: some View {
        Button(action: { isFileImporterPresented = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11))
                Text(String(localized: "Add New Project", table: "Projects"))
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "7C6FFF"))
        )
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Actions

    private func switchToProject(_ project: Project) {
        projectVM.switchProject(to: project, reason: "recentProjectsSidebarSelect")
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folderURL = urls.first else { return }
            addProjectAndSwitch(to: folderURL.standardizedFileURL)
        case .failure(let error):
            if ProjectsPlugin.verbose {
                            ProjectsPlugin.logger.error("File import error: \(error.localizedDescription)")
            }
        }
    }

    private func addProjectAndSwitch(to folderURL: URL) {
        let project = Project(
            name: folderURL.lastPathComponent,
            path: folderURL.path,
            lastUsed: Date()
        )

        store.addProject(name: project.name, path: project.path)
        recentProjectsVM.addProject(project)
        projectVM.switchProject(to: project, reason: "recentProjectsSidebarAddProject")
    }

    // MARK: - Branch Refresh

    private func refreshAllBranches() {
        let paths = recentProjects.map(\.path)
        branchCache.refresh(paths: paths)
    }
}

#Preview {
    ProjectsSidebarView()
        .inRootView()
        .frame(width: 250, height: 400)
}
