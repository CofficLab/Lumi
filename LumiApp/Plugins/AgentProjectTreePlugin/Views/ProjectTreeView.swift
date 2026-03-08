import SwiftUI
import MagicKit

/// 项目文件树视图 - 使用 List 优化性能
struct ProjectTreeView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var rootURLs: [URL] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 文件树内容
            contentView
        }
        .padding(.vertical, 8)
        .background(.background.opacity(0.8))
        .onChange(of: projectViewModel.currentProjectPath) { _, newPath in
            loadProject(at: newPath)
        }
        .onAppear {
            loadProject(at: projectViewModel.currentProjectPath)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("文件树")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: { loadProject(at: projectViewModel.currentProjectPath) }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading && rootURLs.isEmpty {
            loadingView
        } else if rootURLs.isEmpty {
            emptyView
        } else {
            fileTreeList
        }
    }
    
    private var fileTreeList: some View {
        List {
            ForEach(rootURLs, id: \.self) { url in
                FileTreeNodeView(
                    url: url,
                    depth: 0,
                    onSelect: { selectedURL in
                        // 处理文件选择
                    }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
    }
    
    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载中...")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text("暂无项目")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Load Project
    
    private func loadProject(at path: String) {
        guard !path.isEmpty else {
            rootURLs = []
            return
        }
        
        let url = URL(fileURLWithPath: path)
        isLoading = true
        
        Task {
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
}

#Preview {
    ProjectTreeView()
        .environmentObject(ProjectViewModel())
        .frame(width: 250, height: 400)
}
