import SwiftUI

/// Editor for story metadata (title, synopsis).
struct StoryEditorView: View {
    @ObservedObject var viewModel: StoryWriterViewModel
    let story: Story

    @Environment(\.locale) private var locale

    @State private var draft: StoryEditorDraft
    @State private var isEditingTitle = false
    @State private var editTitle = ""
    @State private var exportErrorMessage: String?

    init(viewModel: StoryWriterViewModel, story: Story) {
        self.viewModel = viewModel
        self.story = story
        _draft = State(initialValue: StoryEditorDraft(story: story))
    }

    private func L(_ key: String) -> String {
        pluginLocalization.string(key, locale: locale)
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
                    TextEditor(text: Binding(
                        get: { draft.synopsis },
                        set: { draft.updateSynopsis($0) }
                    ))
                        .frame(minHeight: 120)
                        .border(.separator)
                }

                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Statistics"))
                        .font(.headline)
                    HStack(spacing: 24) {
                        StatItem(title: L("Chapters"), value: "\(viewModel.chapters.count)")
                        StatItem(
                            title: L("Total Words"),
                            // 总字数由 ViewModel 缓存，避免每次按键重算全部章节
                            // （见 issue #1295）。
                            value: "\(viewModel.totalWordCount)"
                        )
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .onChange(of: story) { incoming in
            // 父级在外部更新后送来同一故事的新版本，同步到本地草稿。
            draft.applyExternalUpdate(incoming)
        }
        .onChange(of: draft.synopsis) { newValue in
            guard newValue != draft.baseStory.synopsis else { return }
            let saved = draft.storyToSave()
            draft.markSaved(saved)
            Task {
                await viewModel.updateStory(saved)
            }
        }
        .alert(L("Export Failed"), isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private func saveTitle() {
        isEditingTitle = false
        if !editTitle.isEmpty && editTitle != story.title {
            let saved = draft.storyToSave(title: editTitle)
            draft.markSaved(saved)
            Task {
                await viewModel.updateStory(saved)
            }
        }
    }

    private func exportStory() {
        Task {
            guard let markdown = await viewModel.exportStoryAsMarkdown() else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "\(story.title).md"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            // 整篇文档的编码与原子写放到后台线程，避免大文档/慢磁盘冻结 UI（见 issue #1248）。
            do {
                try await Task.detached(priority: .userInitiated) {
                    try Self.writeMarkdownFile(markdown, to: url)
                }.value
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
    }

    /// 导出文件的编码与落盘。必须是 `nonisolated`，供后台任务调用。
    nonisolated static func writeMarkdownFile(_ markdown: String, to url: URL) throws {
        try markdown.write(to: url, atomically: true, encoding: .utf8)
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