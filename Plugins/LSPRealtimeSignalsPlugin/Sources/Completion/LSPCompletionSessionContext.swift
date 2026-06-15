import EditorService
import Foundation

/// Minimal session surface used by completion resolution (test seam).
@MainActor
public protocol LSPCompletionSessionContext: AnyObject {
    var currentFileURL: URL? { get }
    var languageId: String { get }
    var semanticCapability: (any SuperEditorSemanticCapability)? { get }
}

extension EditorState: LSPCompletionSessionContext {
    public var languageId: String {
        detectedLanguage?.tsName ?? detectedLanguage?.languageId ?? "swift"
    }
}
