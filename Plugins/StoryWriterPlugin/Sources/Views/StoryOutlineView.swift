import SwiftUI

/// Left pane (rail tab): story picker dropdown + chapter tree.
///
/// When used as a registered rail tab, instantiate `StoryOutlineRootView` so the
/// view model is fetched from `RuntimeBridge`. Pass a view model explicitly when
/// embedding inside another container.
struct StoryOutlineView: View {
    @ObservedObject var viewModel: StoryWriterViewModel

    @Environment(\.locale) private var locale

    @State private var showingNewStoryDialog = false
    @State private var newStoryTitle = ""
    @State private var showingNewChapterDialog = false
    @State private var newChapterTitle = ""

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar: story picker dropdown + new/import actions.
            HStack(spacing: 8) {
                storyPicker

                Button {
                    showingNewStoryDialog = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(L("Create a new story"))

                if viewModel.currentStoryID != nil {
                    Button {
                        importMarkdown()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .help(L("Import Markdown file as a new chapter"))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .border(.separator)

            // Chapter tree fills the remaining vertical space.
            if viewModel.currentStoryID != nil {
                chapterTree
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .alert(L("New Story"), isPresented: $showingNewStoryDialog) {
            TextField(L("Story Title"), text: $newStoryTitle)
            Button(L("Create")) {
                if !newStoryTitle.isEmpty {
                    let title = newStoryTitle
                    newStoryTitle = ""
                    Task {
                        await viewModel.createStory(title: title)
                    }
                }
            }
            Button(L("Cancel"), role: .cancel) {
                newStoryTitle = ""
            }
        } message: {
            Text(L("Enter a title for the new story."))
        }
        .alert(L("New Chapter"), isPresented: $showingNewChapterDialog) {
            TextField(L("Chapter Title"), text: $newChapterTitle)
            Button(L("Create")) {
                if !newChapterTitle.isEmpty {
                    let title = newChapterTitle
                    newChapterTitle = ""
                    Task {
                        await viewModel.createChapter(title: title)
                    }
                }
            }
            Button(L("Cancel"), role: .cancel) {
                newChapterTitle = ""
            }
        } message: {
            Text(L("Enter a title for the new chapter."))
        }
    }

    // MARK: - Story picker dropdown

    /// Dropdown menu for selecting the active story.
    @ViewBuilder
    private var storyPicker: some View {
        Menu {
            if viewModel.stories.isEmpty {
                Text(L("No story selected"))
            } else {
                ForEach(viewModel.stories) { story in
                    Button {
                        Task {
                            await viewModel.selectStory(id: story.id)
                        }
                    } label: {
                        if story.id == viewModel.currentStoryID {
                            Label(story.title, systemImage: "checkmark")
                        } else {
                            Text(story.title)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.blue)
                Text(currentStoryTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
        .help(L("Story Outline"))
    }

    private var currentStoryTitle: String {
        if let id = viewModel.currentStoryID,
           let story = viewModel.stories.first(where: { $0.id == id }) {
            return story.title
        }
        return L("No story selected")
    }

    // MARK: - Chapter tree

    @ViewBuilder
    private var chapterTree: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label(L("Chapters"), systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    showingNewChapterDialog = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary)

            if viewModel.chapters.isEmpty {
                Text(L("No chapter content yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.chapters) { chapter in
                            OutlineRow(
                                title: chapter.title,
                                systemImage: "doc.text",
                                isSelected: viewModel.selectedNodeID == chapter.id
                            ) {
                                viewModel.selectedNodeID = chapter.id
                                viewModel.selectedNodeKind = .chapter
                            } onDelete: {
                                Task {
                                    await viewModel.deleteChapter(id: chapter.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func importMarkdown() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let title = url.deletingPathExtension().lastPathComponent
                    await viewModel.importMarkdownAsChapter(title: title, content: content)
                } catch {
                    print("Failed to import Markdown: \(error)")
                }
            }
        }
    }
}

// MARK: - Outline Row

private struct OutlineRow: View {
    @Environment(\.locale) private var locale

    let title: String
    let systemImage: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(L("Delete"), role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Root View (Rail Entry Point)

/// Entry point view that retrieves the view model from `RuntimeBridge`.
///
/// Used as the content of the registered rail tab so the left pane can be
/// contributed via `LumiPlugin.panelRailTabItems(kernel:)` instead of being
/// hard-wired inside a two-pane container.
struct StoryOutlineRootView: View {
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
        StoryOutlineView(viewModel: viewModel)
    }
}