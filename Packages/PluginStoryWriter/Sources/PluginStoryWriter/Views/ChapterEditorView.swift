import SwiftUI

/// Editor for a chapter (TextEditor + word count).
struct ChapterEditorView: View {
    @ObservedObject var viewModel: StoryWriterViewModel
    @State var chapter: Chapter

    @Environment(\.locale) private var locale

    @State private var isEditingTitle = false
    @State private var editTitle = ""

    private func L(_ key: String) -> String {
        pluginLocalization.string(key, locale: locale)
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
        .onChange(of: chapter.content) { _ in
            // 内存列表即时刷新；磁盘写入防抖合并，避免每次按键都全量编码 + 原子写
            // （见 issue #1246）。
            viewModel.applyChapterInMemory(chapter)
            scheduleSave()
        }
        .onDisappear {
            // 离开编辑器（含切换章节，视图按 chapter.id 重建）时立即落盘最新快照。
            flushSave()
        }
    }

    private func saveTitle() {
        isEditingTitle = false
        if !editTitle.isEmpty && editTitle != chapter.title {
            chapter.title = editTitle
            viewModel.applyChapterInMemory(chapter)
            flushSave()
        }
    }

    /// 防抖保存任务：每次内容变化取消上一个、只保留最新快照，空闲窗口后落盘一次。
    @State private var saveTask: Task<Void, Never>?
    private static let saveDebounce: Duration = .milliseconds(500)

    private func scheduleSave() {
        let snapshot = chapter
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: Self.saveDebounce)
            guard !Task.isCancelled else { return }
            await viewModel.persistChapter(snapshot)
        }
    }

    private func flushSave() {
        let snapshot = chapter
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            await viewModel.persistChapter(snapshot)
        }
    }
}