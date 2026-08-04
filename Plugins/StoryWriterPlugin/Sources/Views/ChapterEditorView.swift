import SwiftUI

/// Editor for a chapter (TextEditor + word count + status).
struct ChapterEditorView: View {
    @ObservedObject var viewModel: StoryWriterViewModel
    @State var chapter: Chapter

    @Environment(\.locale) private var locale

    @State private var isEditingTitle = false
    @State private var editTitle = ""

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundStyle(.blue)

                if isEditingTitle {
                    TextField(L("Chapter Title"), text: $editTitle, onCommit: {
                        saveTitle()
                    })
                    .font(.title2.bold())
                } else {
                    Text(chapter.title)
                        .font(.title2.bold())
                        .onTapGesture(count: 2) {
                            editTitle = chapter.title
                            isEditingTitle = true
                        }
                }

                Spacer()

                // Status picker
                Picker(L("Status"), selection: $chapter.status) {
                    Text(L("Draft")).tag(ChapterStatus.draft)
                    Text(L("In Progress")).tag(ChapterStatus.inProgress)
                    Text(L("Done")).tag(ChapterStatus.done)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                // Delete button
                Button {
                    Task {
                        await viewModel.deleteChapter(id: chapter.id)
                    }
                } label: {
                    Label(L("Delete"), systemImage: "trash")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .border(.separator)

            // Editor
            TextEditor(text: $chapter.content)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer (word count)
            HStack {
                Text(String(format: L("Word Count: %lld"), Int64(chapter.wordCount)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if chapter.targetWordCount > 0 {
                    Text(String(format: L("Target: %lld"), Int64(chapter.targetWordCount)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .border(.separator)
        }
        .onChange(of: chapter.content) { _, _ in
            saveChapter()
        }
        .onChange(of: chapter.status) { _, _ in
            saveChapter()
        }
    }

    private func saveTitle() {
        isEditingTitle = false
        if !editTitle.isEmpty && editTitle != chapter.title {
            chapter.title = editTitle
            saveChapter()
        }
    }

    private func saveChapter() {
        Task {
            await viewModel.updateChapter(chapter)
        }
    }
}