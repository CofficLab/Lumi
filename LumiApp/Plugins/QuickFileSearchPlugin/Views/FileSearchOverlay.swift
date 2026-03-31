import Foundation
import SwiftUI

/// 文件搜索覆盖层
///
/// 监听项目变化和快捷键事件，在原有内容上叠加搜索框
struct FileSearchOverlay<Content: View>: View {
    /// 项目 ViewModel
    @EnvironmentObject private var projectVM: ProjectVM

    /// 热键管理器
    @StateObject private var hotkeyManager = FileSearchHotkeyManager.shared

    /// 搜索服务
    @StateObject private var searchService = FileSearchService.shared

    let content: Content

    var body: some View {
        ZStack {
            // 原有应用内容
            content

            // 悬浮搜索框
            if hotkeyManager.isOverlayVisible {
                FileSearchPanelView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(999)
            }
        }
        .onAppear {
            handleOnAppear()
        }
        .onChange(of: projectVM.currentProjectPath) { _, newPath in
            handleProjectPathChange(newPath)
        }
        .onChange(of: searchService.searchQuery) { _, _ in
            searchService.onSearchQueryChanged()
        }
    }
}

// MARK: - Event Handlers

extension FileSearchOverlay {
    /// 视图出现时的初始化
    private func handleOnAppear() {
        // 初始化索引
        if !projectVM.currentProjectPath.isEmpty {
            searchService.updateProject(path: projectVM.currentProjectPath)
        }
    }

    /// 处理项目路径变化
    private func handleProjectPathChange(_ newPath: String) {
        guard !newPath.isEmpty else {
            searchService.clearIndex()
            return
        }

        searchService.updateProject(path: newPath)
    }
}

// MARK: - Preview

#Preview("File Search Overlay") {
    FileSearchOverlay(content: Text("Content"))
        .inRootView()
}
