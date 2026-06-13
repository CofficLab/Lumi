import Foundation
import SwiftTreeSitter

/// Thread-safe language registry populated by editor language plugins.
public final class LanguageRegistry: ObservableObject, @unchecked Sendable {
    public static let shared = LanguageRegistry()

    private let lock = NSLock()
    private var descriptors: [EditorLanguageDescriptor] = []
    private var descriptorsById: [String: EditorLanguageDescriptor] = [:]
    private var extensionToLanguageId: [String: String] = [:]
    private var grammars: [String: any LanguageGrammarProviding] = [:]

    private init() {}

    public func reset() {
        lock.lock()
        descriptors = []
        descriptorsById = [:]
        extensionToLanguageId = [:]
        grammars = [:]
        lock.unlock()
    }

    public func register(_ descriptor: EditorLanguageDescriptor) {
        lock.lock()
        defer { lock.unlock() }
        guard descriptorsById[descriptor.languageId] == nil else { return }
        descriptors.append(descriptor)
        descriptorsById[descriptor.languageId] = descriptor
        for ext in descriptor.fileExtensions {
            extensionToLanguageId[ext.lowercased()] = descriptor.languageId
        }
    }

    public func registerGrammarProvider(_ provider: any LanguageGrammarProviding) {
        lock.lock()
        grammars[provider.grammarId] = provider
        lock.unlock()
    }

    public var availableLanguageIDs: [String] {
        lock.lock()
        let ids = descriptors.map(\.languageId).sorted()
        lock.unlock()
        return ids
    }

    public func descriptor(for languageId: String) -> EditorLanguageDescriptor? {
        lock.lock()
        let value = descriptorsById[languageId]
        lock.unlock()
        return value
    }

    public func grammar(for grammarId: String) -> (any LanguageGrammarProviding)? {
        lock.lock()
        let value = grammars[grammarId]
        lock.unlock()
        return value
    }

    public func lspLanguageId(forExtension ext: String) -> String? {
        lock.lock()
        let languageId = extensionToLanguageId[ext.lowercased()]
        let lspId = languageId.flatMap { descriptorsById[$0]?.lspLanguageId }
        lock.unlock()
        return lspId
    }

    public func detectLanguage(
        url: URL,
        prefixBuffer: String? = nil,
        suffixBuffer: String? = nil
    ) -> EditorLanguageContext {
        lock.lock()
        let snapshot = descriptors
        lock.unlock()
        return LanguageDetection.detect(
            descriptors: snapshot,
            url: url,
            prefixBuffer: prefixBuffer,
            suffixBuffer: suffixBuffer
        )
    }

    public func context(for languageId: String) -> EditorLanguageContext? {
        guard let descriptor = descriptor(for: languageId) else { return nil }
        return EditorLanguageContext(descriptor: descriptor)
    }

    public func context(forHighlightGrammarId grammarId: String) -> EditorLanguageContext? {
        lock.lock()
        let match = descriptors.first { $0.highlightLanguageId == grammarId }
        lock.unlock()
        guard let descriptor = match else { return nil }
        return EditorLanguageContext(descriptor: descriptor)
    }

    public func treeSitterLanguage(for context: EditorLanguageContext) -> Language? {
        guard let provider = grammar(for: context.highlightLanguageId) else { return nil }
        guard let pointer = provider.treeSitterLanguage() else { return nil }
        return Language(language: pointer)
    }

    public func highlightQuery(for context: EditorLanguageContext) -> Query? {
        guard let provider = grammar(for: context.highlightLanguageId) else { return nil }
        let parentURLs: [URL]
        if let parentId = context.descriptor.parentHighlightLanguageId,
           let parent = grammar(for: parentId) {
            parentURLs = parent.highlightQueryURLs()
        } else {
            parentURLs = []
        }
        return LanguageQueryRegistry.shared.query(
            for: context.highlightLanguageId,
            highlightURLs: provider.highlightQueryURLs(),
            parentHighlightURLs: parentURLs,
            language: treeSitterLanguage(for: context)
        )
    }
}
