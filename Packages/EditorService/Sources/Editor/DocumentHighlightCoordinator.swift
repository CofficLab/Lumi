import AppKit
import EditorLanguageRuntime
import EditorSource
import Foundation

@MainActor
public final class DocumentHighlightCoordinator {
    public let cache: DocumentHighlightCache
    public let documentStore: TreeSitterDocumentStore

    private weak var treeSitterClient: TreeSitterClient?
    private weak var textViewController: TextViewController?
    private var attributesProvider: ((CaptureName?) -> [NSAttributedString.Key: Any])?

    private var pendingActivation: PendingActivation?

    private struct PendingActivation {
        let fileURL: URL
        let content: String
        let language: EditorLanguageContext
    }

    public init(
        cache: DocumentHighlightCache = DocumentHighlightCache(),
        documentStore: TreeSitterDocumentStore = TreeSitterDocumentStore()
    ) {
        self.cache = cache
        self.documentStore = documentStore
    }

    public func configure(
        treeSitterClient: TreeSitterClient?,
        textViewController: TextViewController?,
        attributesProvider: @escaping (CaptureName?) -> [NSAttributedString.Key: Any]
    ) {
        self.treeSitterClient = treeSitterClient
        self.textViewController = textViewController
        self.attributesProvider = attributesProvider
        treeSitterClient?.documentStore = documentStore
        flushPendingActivationIfNeeded()
    }

    public func willDeactivate(
        fileURL: URL?,
        content: String,
        language: EditorLanguageContext
    ) {
        guard let fileURL else { return }
        guard !content.isEmpty else { return }

        let key = DocumentHighlightKey(
            fileURL: fileURL,
            content: content,
            languageId: language.languageId
        )

        if let snapshot = textViewController?.exportHighlightSnapshot(
            highlightRevision: cache.highlightRevision,
            key: key
        ) {
            cache.store(snapshot)
            return
        }

        if let existing = cache.snapshot(for: key) {
            cache.store(existing)
        }
    }

    @discardableResult
    public func activate(
        fileURL: URL,
        content: String,
        language: EditorLanguageContext,
        textStorage: NSTextStorage?
    ) -> Bool {
        let key = DocumentHighlightKey(
            fileURL: fileURL,
            content: content,
            languageId: language.languageId
        )

        let restoredFromCache = restoreSnapshotIfAvailable(
            key: key,
            content: content,
            language: language,
            textStorage: textStorage
        )

        attachTreeSitter(documentKey: key, content: content, language: language)

        if restoredFromCache {
            textViewController?.restoreHighlightSnapshot(
                key: key,
                content: content,
                highlightRevision: cache.highlightRevision,
                runs: cache.snapshot(for: key)?.runs
            )
        }

        return restoredFromCache
    }

    public func invalidateCurrentFile(fileURL: URL?, content: String, language: EditorLanguageContext) {
        guard let fileURL else { return }
        let key = DocumentHighlightKey(
            fileURL: fileURL,
            content: content,
            languageId: language.languageId
        )
        cache.invalidate(key: key)
    }

    public func handleThemeChange(textStorage: NSTextStorage?, content: String, fileURL: URL?, language: EditorLanguageContext) {
        guard let fileURL, let textStorage, !content.isEmpty else { return }
        let key = DocumentHighlightKey(
            fileURL: fileURL,
            content: content,
            languageId: language.languageId
        )
        guard let snapshot = cache.snapshot(for: key),
              let attributesProvider else { return }

        SyntaxHighlightRestorer.reapplyTheme(
            snapshot: snapshot,
            to: textStorage,
            content: content,
            highlightRevision: cache.highlightRevision,
            attributesFor: attributesProvider
        )
        textViewController?.restoreHighlightSnapshot(
            key: key,
            content: content,
            highlightRevision: cache.highlightRevision,
            runs: snapshot.runs
        )
    }

    public func bumpHighlightRevision() {
        cache.bumpHighlightRevision()
        documentStore.invalidateAll()
    }

    private func restoreSnapshotIfAvailable(
        key: DocumentHighlightKey,
        content: String,
        language: EditorLanguageContext,
        textStorage: NSTextStorage?
    ) -> Bool {
        guard let snapshot = cache.snapshot(for: key) else { return false }
        guard let textStorage, let attributesProvider else {
            pendingActivation = PendingActivation(
                fileURL: key.standardizedFileURL,
                content: content,
                language: language
            )
            return false
        }

        return SyntaxHighlightRestorer.apply(
            snapshot: snapshot,
            to: textStorage,
            content: content,
            highlightRevision: cache.highlightRevision,
            attributesFor: attributesProvider
        )
    }

    private func attachTreeSitter(
        documentKey: DocumentHighlightKey,
        content: String,
        language: EditorLanguageContext
    ) {
        guard let treeSitterClient, let textView = textViewController?.textView else {
            pendingActivation = PendingActivation(
                fileURL: documentKey.standardizedFileURL,
                content: content,
                language: language
            )
            return
        }

        treeSitterClient.attach(
            documentKey: documentKey,
            textView: textView,
            codeLanguage: language
        )
    }

    private func flushPendingActivationIfNeeded() {
        guard let pendingActivation else { return }
        self.pendingActivation = nil
        activate(
            fileURL: pendingActivation.fileURL,
            content: pendingActivation.content,
            language: pendingActivation.language,
            textStorage: textViewController?.textView.textStorage
        )
    }
}
