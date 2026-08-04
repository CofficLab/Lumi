import SwiftUI

/// Editor for story metadata (title, synopsis).
struct StoryEditorView: View {
    @ObservedObject var viewModel: StoryWriterViewModel
    @State var story: Story

    @Environment(\.locale) private var locale

    @State private var isEditingTitle = false
    @State private var editTitle = ""

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "book.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        if isEditingTitle {
                            TextField(L("Story Title"), text: $editTitle, onCommit: {
                                saveTitle()
                            })
                            .font(.title.bold())
                        } else {
                            Text(story.title)
                                .font(.title.bold())
                                .onTapGesture(count: 2) {
                                    editTitle = story.title
                                    isEditingTitle = true
                                }
                        }
                        Text(String(
                            format: L("Last edited: %@"),
                            story.updatedAt.formatted(date: .abbreviated, time: .shortened)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        exportStory()
                    } label: {
                        Label(L("Export"), systemImage: "square.and.arrow.up")
                    }
                    .help(L("Export story as Markdown"))
                    Button {
                        Task {
                            await viewModel.deleteStory(id: story.id)
                        }
                    } label: {
                        Label(L("Delete"), systemImage: "trash")
                    }
                }

                Divider()

                // Synopsis
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Synopsis"))
                        .font(.headline)
                    TextEditor(text: $story.synopsis)
                        .frame(minHeight: 120)
                        .border(.separator)
                }

                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Statistics"))
                        .font(.headline)
                    HStack(spacing: 24) {
                        StatItem(title: L("Chapters"), value: "\(viewModel.chapters.count)")
                        StatItem(title: L("Characters"), value: "\(viewModel.characters.count)")
                        StatItem(
                            title: L("Total Words"),
                            value: "\(viewModel.chapters.reduce(0) { $0 + $1.wordCount })"
                        )
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .onChange(of: story.synopsis) { _, _ in
            saveStory()
        }
    }

    private func saveTitle() {
        isEditingTitle = false
        if !editTitle.isEmpty && editTitle != story.title {
            story.title = editTitle
            saveStory()
        }
    }

    private func saveStory() {
        Task {
            await viewModel.updateStory(story)
        }
    }

    private func exportStory() {
        Task {
            guard let markdown = await viewModel.exportStoryAsMarkdown() else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "\(story.title).md"
            if panel.runModal() == .OK, let url = panel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

private struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
    }
}