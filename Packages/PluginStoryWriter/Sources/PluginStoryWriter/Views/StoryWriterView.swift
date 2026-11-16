import SwiftUI

/// Main view for the Story Writer plugin.
///
/// Renders only the editor pane (right side of the original two-pane layout).
/// The outline pane (left side) is now contributed by the plugin via
/// `LumiPlugin.panelRailTabItems(kernel:)`.
struct StoryWriterView: View {
    @ObservedObject var viewModel: StoryWriterViewModel

    @Environment(\.locale) private var locale

    private func L(_ key: String) -> String {
        pluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        Group {
            switch viewModel.selectedNodeKind {
            case .story:
                if let story = viewModel.currentStory {
                    // 按故事 identity 物化编辑器：切换故事时 SwiftUI 必须重建
                    // StoryEditorView，让 @State draft 以新故事重新初始化。否则
                    // 旧草稿（含旧故事 id 与未保存简介）会被复用，简介更新、删除
                    // 与导出文件名仍指向旧故事，误写/误删原文档（#289）。
                    StoryEditorView(viewModel: viewModel, story: story)
                        .id(story.id)
                } else {
                    emptyState
                }
            case .chapter:
                if let chapter = viewModel.selectedChapter() {
                    ChapterEditorView(viewModel: viewModel, chapter: chapter)
                        .id(chapter.id)
                } else {
                    emptyState
                }
            case .character:
                // Character editing has been removed from the UI; fall back to empty state.
                emptyState
            case .none:
                emptyState
            }
        }
        .onAppear {
            Task {
                await viewModel.loadStories()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L("No story selected"))
                .font(.headline)
            Text(L("Create or import a story to get started."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Root View (Entry Point)

/// Entry point view that retrieves the view model from RuntimeBridge.
struct StoryWriterRootView: View {
    @StateObject private var viewModel: StoryWriterViewModel

    init() {
        // Retrieve viewModel from RuntimeBridge; create a placeholder if not yet initialized.
        if let vm = RuntimeBridge.viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            // Fallback: create a temporary store for preview/testing.
            let tempStore = StoryStore(pluginDirectory: FileManager.default.temporaryDirectory)
            _viewModel = StateObject(wrappedValue: StoryWriterViewModel(store: tempStore))
        }
    }

    var body: some View {
        StoryWriterView(viewModel: viewModel)
    }
}
