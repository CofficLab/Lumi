import Foundation

public enum EditorPreviewState: Equatable, Sendable {
    case empty
    case loading(URL)
    case markdown(URL, String)
    case image(URL)
    case unsupported(URL)
    case failed(URL, String)

    /// Whether the root Content Footer should reserve space for this preview.
    public var showsPreviewFooter: Bool {
        switch self {
        case .loading, .markdown, .image, .failed:
            true
        case .empty, .unsupported:
            false
        }
    }
}

public enum EditorPreviewFileKind: Equatable, Sendable {
    case markdown
    case image
    case unsupported
}

/// View-facing state for the editor preview.
///
/// The selected file's source of truth stays in the kernel Provider; the
/// ViewModel observes the current file through the plugin's narrowed project
/// capability, owns file loading so the SwiftUI view only observes published
/// state and never reaches into a Provider directly.
///
/// Markdown 内容以磁盘为准：保存成功不会产生项目事件，因此选中 Markdown 后
/// 持续比对文件的修改时间与大小，变化即静默重读（#1016）。
@MainActor
public final class EditorPreviewViewModel: ObservableObject {
    @Published public private(set) var state: EditorPreviewState = .empty

    private var loadTask: Task<Void, Never>?
    private var watchTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var watchedFileSignature: FileSignature?
    private let pollInterval: Duration

    private struct FileSignature: Equatable {
        let modificationDate: Date?
        let fileSize: Int?
    }

    init(
        projectCapability: any EditorPreviewProjectCapability,
        pollInterval: Duration = .seconds(1)
    ) {
        self.pollInterval = pollInterval
        updateCurrentFile(projectCapability.currentFileURL)
    }

    func updateCurrentFile(_ fileURL: URL?) {
        let normalizedURL = fileURL?.standardizedFileURL
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()
        watchTask?.cancel()
        watchTask = nil
        watchedFileSignature = nil

        guard let normalizedURL else {
            state = .empty
            return
        }

        switch Self.kind(for: normalizedURL) {
        case .markdown:
            state = .loading(normalizedURL)
            watchedFileSignature = Self.signature(of: normalizedURL)
            startWatching(normalizedURL, generation: generation)
        case .image:
            state = .image(normalizedURL)
            return
        case .unsupported:
            state = .unsupported(normalizedURL)
            return
        }

        loadTask = Task { [weak self] in
            do {
                let content = try await Self.readUTF8File(at: normalizedURL)
                guard !Task.isCancelled else { return }
                self?.apply(.markdown(normalizedURL, content), generation: generation)
            } catch {
                guard !Task.isCancelled else { return }
                self?.apply(
                    .failed(normalizedURL, error.localizedDescription),
                    generation: generation
                )
            }
        }
    }

    static func kind(for url: URL) -> EditorPreviewFileKind {
        let extensionName = url.pathExtension.lowercased()
        if ["md", "markdown", "mdown", "mkdn", "mkd"].contains(extensionName) {
            return .markdown
        }
        if ["png", "jpg", "jpeg", "gif", "webp", "tif", "tiff", "heic", "bmp", "svg"].contains(extensionName) {
            return .image
        }
        return .unsupported
    }

    private nonisolated static func readUTF8File(at url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try String(contentsOf: url, encoding: .utf8)
        }.value
    }

    private static func signature(of url: URL) -> FileSignature? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return nil
        }
        return FileSignature(
            modificationDate: values.contentModificationDate,
            fileSize: values.fileSize
        )
    }

    /// 轮询当前 Markdown 文件，保存或外部写入后静默重读内容。
    private func startWatching(_ url: URL, generation: Int) {
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: self?.pollInterval ?? .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.reloadIfChanged(url, generation: generation)
            }
        }
    }

    private func reloadIfChanged(_ url: URL, generation: Int) {
        guard generation == loadGeneration else { return }
        let currentSignature = Self.signature(of: url)
        guard currentSignature != watchedFileSignature else { return }
        watchedFileSignature = currentSignature
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            do {
                let content = try await Self.readUTF8File(at: url)
                guard !Task.isCancelled else { return }
                self?.apply(.markdown(url, content), generation: generation)
            } catch {
                guard !Task.isCancelled else { return }
                self?.apply(
                    .failed(url, error.localizedDescription),
                    generation: generation
                )
            }
        }
    }

    private func apply(_ nextState: EditorPreviewState, generation: Int) {
        guard generation == loadGeneration else { return }
        state = nextState
    }
}
