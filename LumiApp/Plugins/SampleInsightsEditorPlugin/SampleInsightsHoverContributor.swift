import Foundation

@MainActor
final class SampleInsightsHoverContributor: EditorHoverContentContributor {
    let id = "sample.insights.hover"

    private let glossary: [String: String] = [
        "TODO": "Sample hover: marks a follow-up task that should be revisited before shipping.",
        "FIXME": "Sample hover: marks code that is known-broken or incomplete and should be repaired.",
        "MARK": "Sample hover: marks a logical section in source code and is useful for editor navigation."
    ]

    func provideHoverContent(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard let body = glossary[context.symbol.uppercased()] else { return [] }
        return [
            EditorHoverSuggestion(
                markdown: """
                **\(context.symbol.uppercased())**

                \(body)
                """,
                priority: 30,
                dedupeKey: "sample-hover-\(context.symbol.uppercased())"
            )
        ]
    }
}
