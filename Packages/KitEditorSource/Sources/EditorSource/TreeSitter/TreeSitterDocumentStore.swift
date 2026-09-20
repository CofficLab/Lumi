import EditorLanguageRuntime
import EditorTextView
import Foundation
import SwiftTreeSitter

public final class TreeSitterDocumentStore: @unchecked Sendable {
    public static let defaultCapacity = 32

    private let lock = NSLock()
    private var entries: [DocumentHighlightKey: TreeSitterState] = [:]
    private var accessOrder: [DocumentHighlightKey] = []
    private let capacity: Int

    public init(capacity: Int = TreeSitterDocumentStore.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    public func state(for key: DocumentHighlightKey) -> TreeSitterState? {
        lock.lock()
        defer { lock.unlock() }
        guard let state = entries[key] else { return nil }
        touch(key)
        return state
    }

    @discardableResult
    public func takeState(for key: DocumentHighlightKey) -> TreeSitterState? {
        lock.lock()
        defer { lock.unlock() }
        guard let state = entries.removeValue(forKey: key) else { return nil }
        accessOrder.removeAll { $0 == key }
        return state
    }

    public func store(_ state: TreeSitterState, for key: DocumentHighlightKey) {
        lock.lock()
        defer { lock.unlock() }
        entries[key] = state
        touch(key)
        evictIfNeeded()
    }

    public func remove(key: DocumentHighlightKey) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    public func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        accessOrder.removeAll()
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    public func makeState(
        for key: DocumentHighlightKey,
        language: EditorLanguageContext,
        readCallback: @escaping SwiftTreeSitter.Predicate.TextProvider,
        readBlock: @escaping Parser.ReadBlock
    ) -> TreeSitterState {
        if let existing = takeState(for: key) {
            return existing
        }
        let state = TreeSitterState(
            codeLanguage: language,
            readCallback: readCallback,
            readBlock: readBlock
        )
        store(state, for: key)
        return takeState(for: key) ?? state
    }

    private func touch(_ key: DocumentHighlightKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictIfNeeded() {
        while accessOrder.count > capacity {
            let evicted = accessOrder.removeFirst()
            entries.removeValue(forKey: evicted)
        }
    }
}
