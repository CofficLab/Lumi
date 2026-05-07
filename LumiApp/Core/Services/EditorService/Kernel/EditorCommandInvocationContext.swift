import CodeEditTextView
import Foundation

@MainActor
final class EditorCommandInvocationContext {
    let legacyContext: EditorCommandContext
    let registryContext: CommandContext
    weak var textView: TextView?

    init(
        legacyContext: EditorCommandContext,
        registryContext: CommandContext,
        textView: TextView?
    ) {
        self.legacyContext = legacyContext
        self.registryContext = registryContext
        self.textView = textView
    }
}
