import SwiftUI
import MagicKit

/// 项目文件树视图 - 使用 List 优化性能
struct ProjectTreeView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    
    /// 当前项目根目录下的一级文件 / 文件夹
    @State private var rootURLs: [URL] = []
    
    /// 是否正在加载项目结构
    @State private var isLoading = false
    
    /// 侧边栏中文件树区域的折叠状态
    @AppStorage("Sidebar_ProjectTree_Expanded") private var isExpanded: Bool = true
    
    /// 标题栏 hover 状态，用于高亮交互区域
    @State private var isHeaderHovered: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // 文件树内容
                contentView
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: projectViewModel.currentProjectPath) { _, newPath in
            loadProject(at: newPath)
        }
        .onAppear {
            loadProject(at: projectViewModel.currentProjectPath)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 6) {
            // 折叠箭头
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 16, height: 16)
            
            // 文件树图标
            Image(systemName: "folder.fill")
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
            
            // 标题
            Text("项目文件")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            
            Spacer()
            
            Button(action: { loadProject(at: projectViewModel.currentProjectPath) }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHeaderHovered ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHeaderHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading && rootURLs.isEmpty {
            loadingView
        } else if rootURLs.isEmpty {
            emptyView
        } else {
            List {
                ForEach(rootURLs, id: \.self) { url in
                    FileNodeView(
                        url: url,
                        depth: 0,
                        selectedURL: projectViewModel.selectedFileURL,
                        onSelect: { selectedURL in
                            projectViewModel.selectFile(at: selectedURL)
                        }
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }
            .environment(\.defaultMinListRowHeight, 0)
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .listRowBackground(Color.clear)
            .padding(.horizontal, -8)  
        }
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
}

#Preview {
    ProjectTreeView()
        .environmentObject(ProjectViewModel())
        .frame(width: 250, height: 400)
}
