import Foundation

@MainActor
final class SwiftKeywordHoverContributor: EditorHoverContributor {
    let id = "builtin.swift.keyword-hover"

    private static let docs: [String: String] = [
        "async": """
`async` marks a function that can suspend while awaiting asynchronous work.
""",
        "await": """
`await` waits for an `async` function to complete at a suspension point.
""",
        "actor": """
`actor` defines a reference type with isolated mutable state for data-race safety.
""",
        "struct": """
`struct` defines a value type. Copies create independent values.
""",
        "class": """
`class` defines a reference type. Instances are shared by reference.
"""
    ]

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard context.languageId.lowercased() == "swift" else { return [] }
        let key = context.symbol.lowercased()
        guard let markdown = Self.docs[key] else { return [] }
        return [.init(markdown: markdown, priority: 100)]
    }
}
