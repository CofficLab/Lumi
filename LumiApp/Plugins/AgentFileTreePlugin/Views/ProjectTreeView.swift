import SwiftUI
import MagicKit

/// 项目文件树视图 - 使用 List 优化性能
struct ProjectTreeView: View {
    @EnvironmentObject var projectVM: ProjectVM

    /// 当前项目根目录
    @State private var rootURL: URL?

    /// 当前项目根目录下的一级文件 / 文件夹
    @State private var rootURLs: [URL] = []

    /// 根节点是否展开
    @State private var isRootExpanded: Bool = true

    /// 是否正在加载项目结构
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // 文件树内容
            contentView
        }
        .frame(maxHeight: .infinity)
        .onChange(of: projectVM.currentProjectPath) { _, newPath in
            loadProject(at: newPath)
        }
        .onAppear {
            loadProject(at: projectVM.currentProjectPath)
        }
    }
}

// MARK: - View

extension ProjectTreeView {
    @ViewBuilder
    private var contentView: some View {
        if isLoading && rootURLs.isEmpty {
            loadingView
        } else if rootURLs.isEmpty {
            emptyView
        } else {
            fileList
        }
    }

    private var fileList: some View {
        List {
            if let rootURL = rootURL {
                // 根节点：项目目录
                HStack(spacing: 6) {
                    // 展开箭头
                    Image(systemName: isRootExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .frame(width: 10)

                    // 图标
                    Image(systemName: isRootExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                        .frame(width: 14)

                    // 项目名称
                    Text(rootURL.lastPathComponent)
                        .font(.system(size: 10))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    rowBackground(isSelected: false)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    isRootExpanded.toggle()
                    if isRootExpanded && !isLoading {
                        loadRootChildren()
                    }
                }

                // 根节点的子节点
                if isRootExpanded {
                    ForEach(rootURLs, id: \.self) { url in
                        FileNodeView(
                            url: url,
                            depth: 1,
                            selectedURL: projectVM.selectedFileURL,
                            onSelect: { selectedURL in
                                projectVM.selectFile(at: selectedURL)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 0)
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .listRowBackground(Color.clear)
        .padding(.horizontal, -8)
    }

    private func rowBackground(isSelected: Bool) -> Color {
        return Color.clear
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(String(localized: "Loading...", table: "ProjectTree"))
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "No project", table: "ProjectTree"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Action

extension ProjectTreeView {
    private func loadProject(at path: String) {
        guard !path.isEmpty else {
            rootURL = nil
            rootURLs = []
            return
        }

        let url = URL(fileURLWithPath: path)
        rootURL = url
        isLoading = true

        Task.detached(priority: .userInitiated) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                // 排序：文件夹在前
                let sorted = contents.sorted { a, b in
                    let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if aIsDir == bIsDir {
                        return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
                    }
                    return aIsDir
                }

                await MainActor.run {
                    self.rootURLs = sorted
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.rootURLs = []
                    self.isLoading = false
                }
            }
        }
    }

    private func loadRootChildren() {
        guard let rootURL = rootURL else { return }

        isLoading = true

        Task.detached(priority: .userInitiated) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: rootURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                // 排序：文件夹在前
                let sorted = contents.sorted { a, b in
                    let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if aIsDir == bIsDir {
                        return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
                    }
                    return aIsDir
                }

                await MainActor.run {
                    self.rootURLs = sorted
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.rootURLs = []
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectTreeView()
        .inRootView()
        .frame(width: 250, height: 400)
}
