import Foundation

/// Stable accessibility identifiers for the empty state's UI-test surface.
///
/// UI tests can only assert on what they can locate, and localized copy is the
/// one thing this package must never hard-code into its assertions: the same
/// empty state renders "Start chatting with Lumi", "How can I help you today?"
/// and a project-interpolated sentence depending on the active context. Pinning
/// identifiers here keeps that branching invisible to the tests.
///
/// Kept as a `String` namespace rather than an `enum` so the values can be used
/// directly in `.accessibilityIdentifier(...)` without ceremony.
enum MessageListEmptyA11y {
    /// The empty state shown when no conversation is selected at all.
    static let noSelection = "lumi.message-list-empty.no-selection"
    /// The empty state shown when the selected conversation has no messages.
    static let noMessages = "lumi.message-list-empty.no-messages"
    /// The prompt-suggestion chip flow, present on both empty-state variants.
    static let suggestionFlow = "lumi.message-list-empty.suggestion-flow"
    /// One prompt-suggestion chip, labelled with the suggestion id.
    ///
    /// Suffix carries the id so a test can target a specific suggestion instead
    /// of clicking "whatever the first chip happens to be", which would make the
    /// test depend on provider ordering.
    static func suggestionChip(id: String) -> String {
        "lumi.message-list-empty.suggestion.\(id)"
    }
    /// The bottom activity strip (heatmap + summary + token trend).
    static let activityStrip = "lumi.message-list-empty.activity"
}
