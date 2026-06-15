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

        for url in activeFirst where tasks[url.standardizedFileURL] == nil {
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

        let content: String
        if stateProvider?.currentFileURL?.standardizedFileURL == fileURL,
           let loaded = stateProvider?.content?.string {
            content = loaded
        } else if let loaded = try? EditorTextFileReader.read(fileURL) {
            content = loaded
        } else {
            return
        }

        guard !Task.isCancelled else { return }
        guard !content.isEmpty else { return }

        if stateProvider?.currentFileURL?.standardizedFileURL == fileURL,
           stateProvider?.largeFileMode != .normal {
            return
        }

        let language = LanguageRegistry.shared.detectLanguage(
            url: fileURL,
            prefixBuffer: content.getFirstLines(5),
            suffixBuffer: content.getLastLines(5)
        )
        let resolvedLanguage = language.languageId == "plaintext" ? EditorLanguageContext.plainText : language
        let highlightRevision = await MainActor.run { cache.highlightRevision }

        guard let snapshot = DocumentHighlightPrewarmWorker.buildSnapshot(
            fileURL: fileURL,
            content: content,
            language: resolvedLanguage,
            highlightRevision: highlightRevision
        ) else {
            return
        }

        await MainActor.run {
            cache.store(snapshot)
        }
    }
}
