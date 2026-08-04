import SwiftUI

/// Left pane: story selector + outline tree (chapters + characters).
struct StoryOutlineView: View {
    @ObservedObject var viewModel: StoryWriterViewModel

    @Environment(\.locale) private var locale

    @State private var showingNewStoryDialog = false
    @State private var newStoryTitle = ""

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack(spacing: 8) {
                Button {
                    showingNewStoryDialog = true
                } label: {
                    Label(L("New Story"), systemImage: "plus")
                }
                .help(L("Create a new story"))

                if viewModel.currentStoryID != nil {
                    Button {
                        importMarkdown()
                    } label: {
                        Label(L("Import"), systemImage: "square.and.arrow.down")
                    }
                    .help(L("Import Markdown file as a new chapter"))
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .border(.separator)

            // Story list
            List(selection: $viewModel.currentStoryID) {
                ForEach(viewModel.stories) { story in
                    StoryRow(story: story, viewModel: viewModel)
                        .tag(Optional(story.id))
                }
            }
            .listStyle(.sidebar)

            if viewModel.currentStoryID != nil {
                Divider()
                OutlineTreeView(viewModel: viewModel)
            }
        }
        .alert(L("New Story"), isPresented: $showingNewStoryDialog) {
            TextField(L("Story Title"), text: $newStoryTitle)
            Button(L("Create")) {
                if !newStoryTitle.isEmpty {
                    Task {
                        await viewModel.createStory(title: newStoryTitle)
                        newStoryTitle = ""
                    }
                }
            }
            Button(L("Cancel"), role: .cancel) {
                newStoryTitle = ""
            }
        } message: {
            Text(L("Enter a title for the new story."))
        }
    }

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

// MARK: - Story Row

private struct StoryRow: View {
    let story: Story
    @ObservedObject var viewModel: StoryWriterViewModel

    @Environment(\.locale) private var locale

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        HStack {
            Image(systemName: "book.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.headline)
                Text(String(
                    format: L("Last edited: %@"),
                    story.updatedAt.formatted(date: .abbreviated, time: .shortened)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button(L("Delete"), role: .destructive) {
                Task {
                    await viewModel.deleteStory(id: story.id)
                }
            }
        }
    }
}

// MARK: - Outline Tree

private struct OutlineTreeView: View {
    @ObservedObject var viewModel: StoryWriterViewModel

    @Environment(\.locale) private var locale

    @State private var showingNewChapterDialog = false
    @State private var newChapterTitle = ""
    @State private var showingNewCharacterDialog = false
    @State private var newCharacterName = ""

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chapters section
            OutlineSection(
                title: L("Chapters"),
                systemImage: "doc.text",
                onAdd: { showingNewChapterDialog = true }
            ) {
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

            // Characters section
            OutlineSection(
                title: L("Characters"),
                systemImage: "person.fill",
                onAdd: { showingNewCharacterDialog = true }
            ) {
                ForEach(viewModel.characters) { character in
                    OutlineRow(
                        title: character.name,
                        systemImage: "person.fill",
                        isSelected: viewModel.selectedNodeID == character.id
                    ) {
                        viewModel.selectedNodeID = character.id
                        viewModel.selectedNodeKind = .character
                    } onDelete: {
                        Task {
                            await viewModel.deleteCharacter(id: character.id)
                        }
                    }
                }
            }
        }
        .alert(L("New Chapter"), isPresented: $showingNewChapterDialog) {
            TextField(L("Chapter Title"), text: $newChapterTitle)
            Button(L("Create")) {
                if !newChapterTitle.isEmpty {
                    Task {
                        await viewModel.createChapter(title: newChapterTitle)
                        newChapterTitle = ""
                    }
                }
            }
            Button(L("Cancel"), role: .cancel) {
                newChapterTitle = ""
            }
        } message: {
            Text(L("Enter a title for the new chapter."))
        }
        .alert(L("New Character"), isPresented: $showingNewCharacterDialog) {
            TextField(L("Character Name"), text: $newCharacterName)
            Button(L("Create")) {
                if !newCharacterName.isEmpty {
                    Task {
                        await viewModel.createCharacter(name: newCharacterName)
                        newCharacterName = ""
                    }
                }
            }
            Button(L("Cancel"), role: .cancel) {
                newCharacterName = ""
            }
        } message: {
            Text(L("Enter a name for the new character."))
        }
    }
}

// MARK: - Outline Components

private struct OutlineSection<Content: View>: View {
    let title: String
    let systemImage: String
    let onAdd: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary)

            content
        }
    }
}

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