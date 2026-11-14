import Combine
import EditorLanguageRuntime
import EditorSource
import Foundation
import os

@MainActor
public final class DocumentHighlightPrewarmScheduler {
    public static let defaultMaxConcurrentTasks = 2

    private let cache: DocumentHighlightCache
    private let documentStore: TreeSitterDocumentStore
    private weak var sessionStore: EditorSessionStore?
    private weak var stateProvider: EditorState?

    private var cancellables = Set<AnyCancellable>()
    private var tasks: [URL: Task<Void, Never>] = [:]
    private let maxConcurrentTasks: Int
    private let logger = Logger(
        subsystem: EditorHostEnvironment.current.logSubsystem,
        category: "editor.highlight-prewarm"
    )

    public init(
        cache: DocumentHighlightCache,
        documentStore: TreeSitterDocumentStore,
        sessionStore: EditorSessionStore,
        stateProvider: EditorState,
        maxConcurrentTasks: Int = DocumentHighlightPrewarmScheduler.defaultMaxConcurrentTasks
    ) {
        self.cache = cache
        self.documentStore = documentStore
        self.sessionStore = sessionStore
        self.stateProvider = stateProvider
        self.maxConcurrentTasks = max(1, maxConcurrentTasks)
        observeSessions()
    }

    public func scheduleAllOpenTabs(activeFileURL: URL?) {
        guard let sessionStore else { return }
        let urls = sessionStore.sessions.compactMap(\.fileURL)
        schedule(urls: urls, activeFileURL: activeFileURL)
    }

    public func schedule(urls: [URL], activeFileURL: URL?) {
        let standardizedActive = activeFileURL?.standardizedFileURL
        let desired = Set(urls.map { $0.standardizedFileURL })

        for (url, task) in tasks where !desired.contains(url) {
            task.cancel()
            tasks.removeValue(forKey: url)
        }

        let activeFirst = urls.sorted { lhs, rhs in
            let lhsActive = lhs.standardizedFileURL == standardizedActive
            let rhsActive = rhs.standardizedFileURL == standardizedActive
            if lhsActive != rhsActive { return lhsActive }
            return lhs.path < rhs.path
        }

        for url in activeFirst where tasks[url.standardizedFileURL] == nil {
            guard runningTaskCount < maxConcurrentTasks || url.standardizedFileURL == standardizedActive else {
                continue
            }
            enqueuePrewarm(for: url, isActive: url.standardizedFileURL == standardizedActive)
        }
    }

    public func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private var runningTaskCount: Int {
        tasks.count
    }

    private func observeSessions() {
        sessionStore?.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let sessionStore = self.sessionStore else { return }
                let urls = sessionStore.sessions.compactMap(\.fileURL)
                self.schedule(urls: urls, activeFileURL: self.stateProvider?.currentFileURL)
            }
            .store(in: &cancellables)
    }

    private func enqueuePrewarm(for fileURL: URL, isActive: Bool) {
        let standardizedURL = fileURL.standardizedFileURL
        guard tasks[standardizedURL] == nil else { return }

        tasks[standardizedURL] = Task(priority: isActive ? .userInitiated : .utility) { [weak self] in
            await self?.prewarm(fileURL: standardizedURL)
            await MainActor.run {
                self?.tasks.removeValue(forKey: standardizedURL)
            }
        }
    }

    private func prewarm(fileURL: URL) async {
        guard !Task.isCancelled else { return }

        let isActiveFile = stateProvider?.currentFileURL?.standardizedFileURL == fileURL

        // 活动文件的正文已在内存中；非活动文件在后台读取并施加大小上限。
        let activeContent: String? = isActiveFile ? stateProvider?.content?.string : nil
        if isActiveFile, activeContent == nil { return }

        // 活动文件超过大文件阈值时不做预热（沿用既有策略，避免无谓的解析开销）。
        if isActiveFile, stateProvider?.largeFileMode != .normal { return }

        guard !Task.isCancelled else { return }

        let highlightRevision = await MainActor.run { cache.highlightRevision }

        // 磁盘读取、tree-sitter 解析与 highlight query 全部在后台执行，
        // 主线程只负责取回快照并写入缓存（见 issue #1276）。
        let snapshot = await Task.detached(priority: isActiveFile ? .userInitiated : .utility) { () -> DocumentHighlightSnapshot? in
            let content: String
            if let activeContent {
                content = activeContent
            } else {
                guard let loaded = Self.readFileWithSizeGuard(fileURL) else { return nil }
                content = loaded
            }

            guard !content.isEmpty else { return nil }

            let language = LanguageRegistry.shared.detectLanguage(
                url: fileURL,
                prefixBuffer: content.getFirstLines(5),
                suffixBuffer: content.getLastLines(5)
            )
            let resolvedLanguage = language.languageId == "plaintext" ? EditorLanguageContext.plainText : language

            return DocumentHighlightPrewarmWorker.buildSnapshot(
                fileURL: fileURL,
                content: content,
                language: resolvedLanguage,
                highlightRevision: highlightRevision
            )
        }.value

        guard let snapshot else { return }

        cache.store(snapshot)
    }

    /// 预热允许的最大文件大小。
    ///
    /// 与 `LargeFileMode.mediumThreshold`（1 MB）保持一致：超过该大小的文件
    /// 即使是**非活动标签**也不再预热，避免多 MB 文件被完整读入并解析。
    public nonisolated static let maxPrewarmFileSize = 1024 * 1024

    /// 在后台读取文件正文；超过大小上限时放弃预热。
    ///
    /// - Important: 必须 `nonisolated` —— 该方法在 `Task.detached` 内调用，
    ///   而外层类型标注了 `@MainActor`（见 issue #1276）。
    nonisolated private static func readFileWithSizeGuard(_ fileURL: URL) -> String? {
        if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           fileSize > maxPrewarmFileSize {
            return nil
        }
        guard let content = try? EditorTextFileReader.read(fileURL) else { return nil }
        guard content.utf8.count <= maxPrewarmFileSize else { return nil }
        return content
    }
}
