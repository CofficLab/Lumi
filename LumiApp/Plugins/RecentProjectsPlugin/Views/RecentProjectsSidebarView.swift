import SwiftUI
import MagicKit
import UniformTypeIdentifiers

/// 最近项目侧边栏视图
struct RecentProjectsSidebarView: View {
    @EnvironmentObject var projectVM: ProjectVM
    @State private var isFileImporterPresented = false
    @State private var isDropTargeted = false

    private let store = RecentProjectsStore()

    var body: some View {
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
        .dropDestination(
            for: URL.self,
            action: { urls, _ in
                handleProjectFolderDrop(urls: urls)
            },
            isTargeted: { targeted in
                isDropTargeted = targeted
            }
        )
        .overlay {
            if isDropTargeted {
                DropOverlayCard(
                    title: "松开即可添加项目",
                    subtitle: "将项目文件夹拖到侧边栏，自动加入最近项目并切换"
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
            }
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

        return HStack(spacing: 8) {
            Image(systemName: isSelected ? "folder.fill" : "folder")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 12))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                    .lineLimit(1)
                
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
            DragPreview(fileURL: URL(fileURLWithPath: project.path))
        }
    }
    
    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "No Recent Projects", table: "RecentProjects"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Computed Properties
    
    private var recentProjects: [Project] {
        projectVM.recentProjects
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("添加项目")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
            }

            Text("将项目目录拖动到这里来添加，或者点击下方按钮选择。")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { isFileImporterPresented = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                    Text(String(localized: "Select New Project", table: "RecentProjects"))
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppUI.Color.semantic.primary)
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isDropTargeted ? Color.accentColor.opacity(0.65) : Color.white.opacity(0.14),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 1.5 : 1, dash: [6, 4])
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
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
        projectVM.switchProject(to: project)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folderURL = urls.first else { return }
            addProjectAndSwitch(to: folderURL.standardizedFileURL)
        case .failure(let error):
            RecentProjectsPlugin.logger.error("File import 错误：\(error.localizedDescription)")
        }
    }

    private func handleProjectFolderDrop(urls: [URL]) -> Bool {
        let normalizedURLs = urls.map(\.standardizedFileURL)
        guard let folderURL = normalizedURLs.first(where: { isDirectory($0) }) else {
            return false
        }
        addProjectAndSwitch(to: folderURL)
        return true
    }

    private func addProjectAndSwitch(to folderURL: URL) {
        let project = Project(
            name: folderURL.lastPathComponent,
            path: folderURL.path,
            lastUsed: Date()
        )

        store.addProject(name: project.name, path: project.path)
        projectVM.setRecentProjects(store.loadProjects())
        projectVM.switchProject(to: project)
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

#Preview {
    RecentProjectsSidebarView()
        .inRootView()
        .frame(width: 250, height: 400)
}
