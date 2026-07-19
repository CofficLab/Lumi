import Foundation
import LumiKernel
import SwiftUI
import LumiUI

/// 文件搜索覆盖层
///
/// 监听项目变化和快捷键事件，在原有内容上叠加搜索框
public struct FileSearchOverlay<Content: View>: View {
    /// 热键管理器
    @StateObject private var hotkeyManager = FileSearchHotkeyManager.shared

    /// 搜索服务
    @StateObject private var searchService = FileSearchService.shared

    public let content: Content
    private let projectPathProvider: () -> String
    private let windowIdProvider: () -> UUID?

    public init(
        content: Content,
        projectPathProvider: @escaping () -> String,
        windowIdProvider: @escaping () -> UUID?
    ) {
        self.content = content
        self.projectPathProvider = projectPathProvider
        self.windowIdProvider = windowIdProvider
    }

    public var body: some View {
        ZStack {
            content

            if hotkeyManager.isOverlayVisible(for: windowIdProvider()) {
                FileSearchPanelView(windowIdProvider: windowIdProvider)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(999)
            }
        }
        .onAppear {
            hotkeyManager.startMonitoring()
            handleOnAppear()
        }
        .onChange(of: projectPathProvider()) { _, newPath in
            handleProjectPathChange(newPath)
        }
        .onChange(of: searchService.searchQuery) { _, _ in
            searchService.onSearchQueryChanged()
        }
        .onChange(of: hotkeyManager.targetWindowId) { _, targetWindowId in
            guard targetWindowId == windowIdProvider() else { return }
            handleOnAppear()
        }
    }
}

// MARK: - Event Handlers

extension FileSearchOverlay {
    private func handleOnAppear() {
        let path = projectPathProvider()
        if !path.isEmpty {
            searchService.updateProject(path: path)
        }
    }

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
    FileSearchOverlay(
        content: Text(LumiPluginLocalization.string("Content", bundle: .module)),
        projectPathProvider: { "" },
        windowIdProvider: { nil }
    )
    .inRootView()
}
