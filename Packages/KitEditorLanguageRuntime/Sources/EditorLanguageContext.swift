import Foundation

/// Resolved language for an open editor document.
public struct EditorLanguageContext: Sendable, Equatable, Hashable {
    public let descriptor: EditorLanguageDescriptor

    public init(descriptor: EditorLanguageDescriptor) {
        self.descriptor = descriptor
    }

    public var languageId: String { descriptor.languageId }
    public var highlightLanguageId: String { descriptor.highlightLanguageId }
    public var lspLanguageId: String? { descriptor.lspLanguageId }
    /// Compatibility alias used by legacy editor code paths.
    public var tsName: String { descriptor.highlightLanguageId }
    public var lineCommentString: String { descriptor.lineComment ?? "" }
    public var rangeCommentStrings: (String, String) {
        descriptor.rangeComment ?? ("", "")
    }
    public var extensions: Set<String> { descriptor.fileExtensions }
    public var additionalIdentifiers: Set<String> {
        descriptor.shebangAliases.union(descriptor.additionalModelineIds)
    }
}

public extension EditorLanguageContext {
    static let plainText = EditorLanguageContext(descriptor: .plainText)
}

public extension EditorLanguageDescriptor {
    static let plainText = EditorLanguageDescriptor(
        languageId: "plaintext",
        displayName: "Plain Text",
        fileExtensions: ["txt"],
        highlightLanguageId: "plaintext",
        lspLanguageId: nil
    )
}
