import LumiKernel
import SwiftUI

/// Main view for the Story Writer plugin.
///
/// Two-pane layout:
/// - Left: outline tree (story selector + chapter/character list)
/// - Right: selected node editor
struct StoryWriterView: View {
    @ObservedObject var viewModel: StoryWriterViewModel

    var body: some View {
        HSplitView {
            StoryOutlineView(viewModel: viewModel)
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)

            editorPane
                .frame(minWidth: 400)
        }
        .onAppear {
            Task {
                await viewModel.loadStories()
            }
        }
    }

    @ViewBuilder
    private var editorPane: some View {
        switch viewModel.selectedNodeKind {
        case .story:
            if let story = viewModel.currentStory {
                StoryEditorView(viewModel: viewModel, story: story)
            } else {
                emptyState
            }
        case .chapter:
            if let chapter = viewModel.selectedChapter() {
                ChapterEditorView(viewModel: viewModel, chapter: chapter)
            } else {
                emptyState
            }
        case .character:
            if let character = viewModel.selectedCharacter() {
                CharacterEditorView(viewModel: viewModel, character: character)
            } else {
                emptyState
            }
        case .none:
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No story selected")
                .font(.headline)
            Text("Create or import a story to get started.")
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
