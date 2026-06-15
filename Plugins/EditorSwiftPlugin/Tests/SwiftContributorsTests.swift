@testable import EditorSwiftPlugin
import EditorService
import Testing

@MainActor
@Test func swiftPrimitiveTypeCompletionDoesNotCoverEnumMemberAccess() async {
    let contributor = SwiftPrimitiveTypeCompletionContributor()
    let enumMemberContext = EditorCompletionContext(
        languageId: "swift",
        line: 0,
        character: 22,
        prefix: "",
        isTypeContext: false
    )
    #expect(await contributor.provideSuggestions(context: enumMemberContext).isEmpty)
}

@MainActor
@Test func swiftPrimitiveTypeCompletionRequiresSwiftAndTypeContext() async {
    let contributor = SwiftPrimitiveTypeCompletionContributor()
    let nonSwift = EditorCompletionContext(
        languageId: "python",
        line: 1,
        character: 10,
        prefix: "In",
        isTypeContext: true
    )
    #expect(await contributor.provideSuggestions(context: nonSwift).isEmpty)

    let notTypeContext = EditorCompletionContext(
        languageId: "swift",
        line: 1,
        character: 10,
        prefix: "In",
        isTypeContext: false
    )
    #expect(await contributor.provideSuggestions(context: notTypeContext).isEmpty)
}

@MainActor
@Test func swiftPrimitiveTypeCompletionFiltersByPrefix() async {
    let contributor = SwiftPrimitiveTypeCompletionContributor()
    let context = EditorCompletionContext(
        languageId: "swift",
        line: 1,
        character: 10,
        prefix: "int",
        isTypeContext: true
    )
    let suggestions = await contributor.provideSuggestions(context: context)
    #expect(!suggestions.isEmpty)
    #expect(suggestions.allSatisfy { $0.label.lowercased().hasPrefix("int") })
    #expect(suggestions.contains { $0.label == "Int" })
}

@MainActor
@Test func swiftPrimitiveTypeCompletionReturnsAllTypesForEmptyPrefix() async {
    let contributor = SwiftPrimitiveTypeCompletionContributor()
    let context = EditorCompletionContext(
        languageId: "swift",
        line: 1,
        character: 10,
        prefix: "",
        isTypeContext: true
    )
    let suggestions = await contributor.provideSuggestions(context: context)
    #expect(suggestions.count >= 10)
    #expect(suggestions.contains { $0.label == "String" })
}

@MainActor
@Test func swiftKeywordHoverContributorDocumentsKnownKeywords() async {
    let contributor = EditorSwiftKeywordHoverContributor()
    let nonSwift = EditorHoverContext(languageId: "python", line: 1, character: 1, symbol: "async")
    #expect(await contributor.provideHover(context: nonSwift).isEmpty)

    let asyncHover = EditorHoverContext(languageId: "swift", line: 1, character: 1, symbol: "async")
    let suggestions = await contributor.provideHover(context: asyncHover)
    #expect(suggestions.count == 1)
    #expect(suggestions[0].markdown.contains("async"))
}

@MainActor
@Test func swiftSelectionCodeActionContributorRequiresSelection() async {
    let contributor = SwiftSelectionCodeActionContributor()
    let empty = EditorCodeActionContext(languageId: "swift", line: 1, character: 1, selectedText: "   ")
    #expect(await contributor.provideCodeActions(context: empty).isEmpty)

    let withSelection = EditorCodeActionContext(languageId: "swift", line: 1, character: 1, selectedText: "value")
    let actions = await contributor.provideCodeActions(context: withSelection)
    #expect(actions.count == 2)
    #expect(actions.contains { $0.command == "builtin.swift.wrap-print" })
    #expect(actions.contains { $0.command == "builtin.swift.wrap-debug" })
}
