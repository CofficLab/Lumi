import EditorService
import Foundation

/// Result when semantic preflight blocks the LSP completion path.
public enum LSPCompletionPreflightBlockedResult: Equatable, Sendable {
    case showPluginSuggestions(count: Int)
    case suppressed
}

public enum LSPCompletionPreflightGate {
    /// When preflight fails, LSP is skipped entirely. Plugin suggestions may still appear.
    public static func blockedResult(pluginSuggestionCount: Int) -> LSPCompletionPreflightBlockedResult {
        pluginSuggestionCount > 0
            ? .showPluginSuggestions(count: pluginSuggestionCount)
            : .suppressed
    }

    /// Whether to call sourcekit-lsp (or other LSP) for this completion request.
    ///
    /// Soft preflight failures still allow LSP when built-in plugin contributors cannot satisfy
    /// the context — notably enum/member access after `.`.
    public static func shouldQueryLSP(
        preflightError: EditorLanguageFeatureError?,
        context: LSPCompletionContext
    ) -> Bool {
        guard preflightError != nil else { return true }
        if context.isMemberAccessContext { return true }
        if pluginCanSatisfy(context: context) { return false }
        return true
    }

    /// Member-access completions (e.g. enum `.case`) require LSP; built-in plugin contributors do not cover them.
    public static func pluginCanSatisfy(context: LSPCompletionContext) -> Bool {
        context.isTypeContext
    }
}
