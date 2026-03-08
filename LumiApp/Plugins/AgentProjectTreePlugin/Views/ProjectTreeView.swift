import SwiftUI
import MagicKit
import OSLog

/// 项目文件树视图
struct ProjectTreeView: View {
    @StateObject private var viewModel = FileTreeViewModel()
    @EnvironmentObject var projectViewModel: ProjectViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            ProjectTreeHeader(
                projectRoot: viewModel.projectRoot,
                onRefresh: { viewModel.refresh() }
            )
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 文件树内容
            contentView
        }
        .padding(.vertical, 8)
        .background(.background.opacity(0.8))
        .onChange(of: projectViewModel.currentProjectPath) { _, newPath in
            viewModel.loadProject(at: newPath)
        }
        .onAppear {
            let projectPath = projectViewModel.currentProjectPath
            if !projectPath.isEmpty {
                viewModel.loadProject(at: projectPath)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.rootNodes.isEmpty {
            ProjectTreeLoadingView()
        } else if viewModel.rootNodes.isEmpty {
            ProjectTreeEmptyView()
        } else {
            fileTreeScrollView
        }
    }
    
    private var fileTreeScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.rootNodes) { node in
                    FileTreeNodeView(
                        node: node,
                        depth: 0,
                        viewModel: viewModel
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    ProjectTreeView()
        .environmentObject(ProjectViewModel())
        .frame(width: 250, height: 400)
}
