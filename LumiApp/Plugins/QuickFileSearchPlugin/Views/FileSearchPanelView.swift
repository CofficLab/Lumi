import SwiftUI
import AppKit

/// 文件搜索面板视图
///
/// 悬浮在应用主界面之上的文件搜索框
struct FileSearchPanelView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @StateObject private var hotkeyManager = FileSearchHotkeyManager.shared
    @StateObject private var searchService = FileSearchService.shared

    @FocusState private var isSearchFocused: Bool
    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // 搜索输入框区域
            searchHeader

            // 只有在有搜索内容时才显示分隔线和结果
            if !searchService.searchQuery.isEmpty {
                Divider()
                
                // 计算结果列表高度
                searchResultsList
            }
        }
        .frame(width: searchService.searchQuery.isEmpty ? 400 : 600)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onChange(of: searchService.searchResults.count) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack(spacing: 12) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 20)

            // 搜索输入框
            TextField("搜索文件...", text: $searchService.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .onSubmit {
                    selectFirstResult()
                }
                .overlay(
                    Group {
                        if searchService.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 8)
                        }
                    }
                )

            // 快捷键提示（仅在无输入时显示）
            if searchService.searchQuery.isEmpty {
                Text("Esc")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(12)
        .frame(height: 44)  // 固定头部高度
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        Group {
            if searchService.isLoading && searchService.searchQuery.isEmpty {
                // 加载中
                loadingView
            } else if searchService.searchResults.isEmpty && !searchService.searchQuery.isEmpty {
                // 无结果 - 使用较小的固定高度
                emptyResultView
                    .frame(height: 100)
            } else if searchService.searchResults.isEmpty && searchService.searchQuery.isEmpty {
                // 空状态（不应该显示）
                EmptyView()
            } else {
                // 结果列表 - 限制最大高度
                resultsList
                    .frame(maxHeight: 300)  // 最多显示 300px 高度的结果
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在索引文件...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    private var emptyResultView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("未找到匹配文件")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(searchService.searchResults.enumerated()), id: \.element.id) { index, result in
                    FileSearchResultRow(
                        result: result,
                        isSelected: index == selectedIndex
                    )
                    .onTapGesture {
                        selectFile(at: index)
                    }
                    .onHover { hovering in
                        if hovering {
                            selectedIndex = index
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func selectFirstResult() {
        guard !searchService.searchResults.isEmpty else { return }
        selectFile(at: 0)
    }

    private func selectFile(at index: Int) {
        guard index >= 0 && index < searchService.searchResults.count else { return }

        let result = searchService.searchResults[index]
        searchService.selectFile(result)
        hotkeyManager.hideOverlay()
    }

    // MARK: - Keyboard Handling

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .upArrow:
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled

        case .downArrow:
            if selectedIndex < searchService.searchResults.count - 1 {
                selectedIndex += 1
            }
            return .handled

        case .escape:
            hotkeyManager.hideOverlay()
            return .handled

        case .return:
            selectFile(at: selectedIndex)
            return .handled

        default:
            return .ignored
        }
    }
}

// MARK: - Preview

#Preview("File Search Panel - Empty") {
    FileSearchPanelView()
        .inRootView()
        .frame(width: 500, height: 200)
}

#Preview("File Search Panel - With Results") {
    FileSearchPanelView()
        .inRootView()
        .frame(width: 800, height: 500)
}
