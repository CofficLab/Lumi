//
//  TreeSitterClient.swift
//  EditorSource
//
//  Created by Khan Winter on 9/12/22.
//

import Foundation
import EditorTextView
import EditorLanguageRuntime
import SwiftTreeSitter
import OSLog

/// # TreeSitterClient
///
/// ``TreeSitterClient`` is an class that manages a tree-sitter syntax tree and provides an API for notifying that
/// tree of edits and querying the tree. This type also conforms to ``HighlightProviding`` to provide syntax
/// highlighting.
///
/// The APIs this object provides can perform either asynchronously or synchronously. All calls to this object must
/// first be dispatched from the main queue to ensure serial access to internal properties. Any synchronous methods
/// can throw an ``TreeSitterClientExecutor/Error/syncUnavailable`` error if an asynchronous or synchronous call is
/// already being made on the object. In those cases it is up to the caller to decide whether or not to retry
/// asynchronously.
///
/// The only exception to the above rule is the ``HighlightProviding`` conformance methods. The methods for that
/// implementation may return synchronously or asynchronously depending on a variety of factors such as document
/// length, edit length, highlight length and if the object is available for a synchronous call.
public final class TreeSitterClient: HighlightProviding {
    static let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "TreeSitterClient")
    nonisolated(unsafe) static var verbose: Bool = false

    enum TreeSitterClientError: Error {
        case invalidEdit
    }

    // MARK: - Properties

    /// A callback to use to efficiently fetch portions of text.
    var readBlock: Parser.ReadBlock?

    /// A callback used to fetch text for queries.
    var readCallback: SwiftTreeSitter.Predicate.TextProvider?

    /// The internal tree-sitter layer tree object.
    var state: TreeSitterState?

    package var executor: TreeSitterExecutor = .init()

    /// The end point of the previous edit.
    private var oldEndPoint: Point?

    package var pendingEdits: Atomic<[InputEdit]> = Atomic([])

    public var documentStore: TreeSitterDocumentStore?

    package private(set) var attachedDocumentKey: DocumentHighlightKey?


    /// Optional flag to force every operation to be done on the caller's thread.
    package var forceSyncOperation: Bool = false

    public init() { }

    // MARK: - Constants

    public enum Constants {
        /// The maximum amount of limits a cursor can match during a query.
        ///
        /// Used to ensure performance in large files, even though we generally limit the query to the visible range.
        /// Neovim encountered this issue and uses 64 for their limit. Helix uses 256 due to issues with some
        /// languages when using 64.
        /// See: [github.com/neovim](https://github.com/neovim/neovim/issues/14897)
        /// And: [github.com/helix-editor](https://github.com/helix-editor/helix/pull/4830)
        public static var matchLimit = 256

        /// The timeout for parsers to re-check if a task is canceled. This constant represents the period between
        /// checks and is directly related to editor responsiveness.
        /// Optimized: Increased from 0.05s to 0.1s to reduce timeout-induced re-parsing.
        public static var parserTimeout: TimeInterval = 0.1

        /// The maximum length of an edit before it must be processed asynchronously
        /// Optimized: Reduced from 1024 to 512 to avoid main thread blocking.
        public static var maxSyncEditLength: Int = 512

        /// The maximum length a document can be before all queries and edits must be processed asynchronously.
        /// Optimized: Reduced from 1MB to 500KB to improve responsiveness with large files.
        public static var maxSyncContentLength: Int = 500_000

        /// The maximum length a query can be before it must be performed asynchronously.
        public static var maxSyncQueryLength: Int = 4096

        /// The number of characters to read in a read block.
        ///
        /// This has diminishing returns on the number of times the read block is called as this number gets large.
        public static let charsToReadInBlock: Int = 4096

        /// The duration before a long parse notification is sent.
        public static var longParseTimeout: Duration = .seconds(0.5)

        /// The notification name sent when a long parse is detected.
        public static let longParse: Notification.Name = .init("EditorSource.longParseNotification")

        /// The notification name sent when a long parse is finished.
        public static let longParseFinished: Notification.Name = .init(
            "EditorSource.longParseFinishedNotification"
        )

        /// Posted on the main queue after the initial tree-sitter state is ready.
        public static let stateDidUpdate: Notification.Name = .init("EditorSource.treeSitterStateDidUpdate")

        /// The duration tasks sleep before checking if they're runnable.
        ///
        /// Lower than 1ms starts causing bad lock contention, much higher reduces responsiveness with diminishing
        /// returns on CPU efficiency.
        public static let taskSleepDuration: Duration = .milliseconds(10)
    }

    // MARK: - HighlightProviding

    /// Set up the client with a text view and language.
    /// - Parameters:
    ///   - textView: The text view to use as a data source.
    ///               A weak reference will be kept for the lifetime of this object.
    ///   - codeLanguage: The language to use for parsing.
    public func setUp(textView: TextView, codeLanguage: EditorLanguageContext) {
        let key = attachedDocumentKey ?? DocumentHighlightKey(
            fileURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("untitled"),
            content: textView.string,
            languageId: codeLanguage.languageId
        )
        attach(documentKey: key, textView: textView, codeLanguage: codeLanguage)
    }

    public func attach(
        documentKey: DocumentHighlightKey,
        textView: TextView,
        codeLanguage: EditorLanguageContext
    ) {
        if Self.verbose {
            Self.logger.debug(
                "TreeSitterClient attaching document: \(documentKey.standardizedFileURL.path, privacy: .public)"
            )
        }

        let readBlock = textView.createReadBlock()
        let readCallback = textView.createReadCallback()
        self.readBlock = readBlock
        self.readCallback = readCallback
        self.attachedDocumentKey = documentKey

        if let documentStore,
           let cachedState = documentStore.takeState(for: documentKey) {
            self.state = cachedState
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Constants.stateDidUpdate, object: self)
            }
            return
        }

        let operation = { [weak self] in
            guard let self else { return }
            let state = TreeSitterState(
                codeLanguage: codeLanguage,
                readCallback: readCallback,
                readBlock: readBlock
            )
            self.state = state
            self.documentStore?.store(state, for: documentKey)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Constants.stateDidUpdate, object: self)
            }
        }

        executor.cancelAll(below: .all)
        if forceSyncOperation {
            executor.execSync(operation)
        } else {
            executor.execAsync(priority: .reset, operation: operation, onCancel: {})
        }
    }

    public func detach() {
        guard let attachedDocumentKey, let state else { return }
        documentStore?.store(state, for: attachedDocumentKey)
        self.state = nil
        self.attachedDocumentKey = nil
    }

    // MARK: - HighlightProviding

    /// Notifies the highlighter of an edit and in exchange gets a set of indices that need to be re-highlighted.
    /// The returned `IndexSet` should include all indexes that need to be highlighted, including any inserted text.
    /// - Parameters:
    ///   - textView: The text view to use.
    ///   - range: The range of the edit.
    ///   - delta: The length of the edit, can be negative for deletions.
    ///   - completion: The function to call with an `IndexSet` containing all Indices to invalidate.
    public func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        let oldEndPoint: Point = self.oldEndPoint ?? textView.pointForLocation(range.max) ?? .zero
        guard let edit = InputEdit(range: range, delta: delta, oldEndPoint: oldEndPoint, textView: textView) else {
            completion(.failure(TreeSitterClientError.invalidEdit))
            return
        }

        let operation = { [weak self] in
            return self?.applyEdit(edit: edit) ?? IndexSet()
        }

        let longEdit = range.length > Constants.maxSyncEditLength
        let longDocument = textView.documentRange.length > Constants.maxSyncContentLength
        let execAsync = longEdit || longDocument

        if !execAsync || forceSyncOperation {
            let result = executor.execSync(operation)
            if case .success(let invalidatedRanges) = result {
                DispatchQueue.dispatchMainIfNot { completion(.success(invalidatedRanges)) }
                return
            }
        }

        if !forceSyncOperation {
            executor.cancelAll(below: .reset) // Cancel all edits, add it to the pending edit queue
            executor.execAsync(
                priority: .edit,
                operation: { completion(.success(operation())) },
                onCancel: { [weak self] in
                    self?.pendingEdits.mutate { edits in
                        edits.append(edit)
                    }
                    DispatchQueue.dispatchMainIfNot {
                        completion(.failure(HighlightProvidingError.operationCancelled))
                    }
                }
            )
        }
    }

    /// Called before an edit is sent. We use this to set the ``oldEndPoint`` variable so tree-sitter knows where
    /// the document used to end.
    /// - Parameters:
    ///   - textView: The text view used.
    ///   - range: The range that will be edited.
    public func willApplyEdit(textView: TextView, range: NSRange) {
        oldEndPoint = textView.pointForLocation(range.max)
    }

    /// Initiates a highlight query.
    /// - Parameters:
    ///   - textView: The text view to use.
    ///   - range: The range to limit the highlights to.
    ///   - completion: Called when the query completes.
    public func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        let operation: () -> Result<[HighlightRange], Error> = { [weak self] in
            guard let self else { return .success([]) }
            guard self.state != nil else {
                return .failure(HighlightProvidingError.operationCancelled)
            }
            let highlights = self.queryHighlightsForRange(range: range)
                .sorted { $0.range.location < $1.range.location }
            return .success(highlights)
        }

        let longQuery = range.length > Constants.maxSyncQueryLength
        let longDocument = textView.documentRange.length > Constants.maxSyncContentLength
        let execAsync = longQuery || longDocument

        if !execAsync || forceSyncOperation {
            switch executor.execSync(operation) {
            case .success(let queryResult):
                DispatchQueue.dispatchMainIfNot { completion(queryResult) }
                return
            case .failure:
                break
            }
        }

        if !forceSyncOperation {
            executor.execAsync(
                priority: .access,
                operation: {
                    DispatchQueue.dispatchMainIfNot { completion(operation()) }
                },
                onCancel: {
                    DispatchQueue.dispatchMainIfNot {
                        completion(.failure(HighlightProvidingError.operationCancelled))
                    }
                }
            )
        }
    }
}
