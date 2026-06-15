import EditorService
import Testing
@testable import LSPRealtimeSignalsPlugin

@Test func enumMemberAccessContextDetectedAfterDot() {
    let content = "let status: Status = ."
    let offset = content.utf16.count
    let context = LSPCompletionContextAnalyzer.analyze(atOffset: offset, in: content)

    #expect(context.isMemberAccessContext)
    #expect(!context.isTypeContext)
    #expect(context.prefix.isEmpty)
}

@Test func typeContextDetectedAfterColon() {
    let content = "let id: In"
    let offset = content.utf16.count
    let context = LSPCompletionContextAnalyzer.analyze(atOffset: offset, in: content)

    #expect(context.isTypeContext)
    #expect(!context.isMemberAccessContext)
    #expect(context.prefix == "In")
}

@Test func switchCaseDotIsMemberAccessContext() {
    let content = """
    switch value {
    case .
    """
    let offset = content.utf16.count
    let context = LSPCompletionContextAnalyzer.analyze(atOffset: offset, in: content)

    #expect(context.isMemberAccessContext)
    #expect(!context.isTypeContext)
}

@Test func preflightGateStillQueriesLSPForMemberAccessDespiteSoftPreflight() {
    let memberContext = LSPCompletionContext(prefix: "", isTypeContext: false, isMemberAccessContext: true)
    let error = EditorLanguageFeatureError(
        domain: "xcode.semantic",
        code: "file-not-in-target",
        message: "File not in target",
        suggestion: nil
    )

    #expect(LSPCompletionPreflightGate.shouldQueryLSP(preflightError: error, context: memberContext))
}

@Test func preflightGateSkipsLSPForTypeContextWhenPluginsCanHelp() {
    let typeContext = LSPCompletionContext(prefix: "In", isTypeContext: true, isMemberAccessContext: false)
    let error = EditorLanguageFeatureError(
        domain: "xcode.semantic",
        code: "build-context-unavailable",
        message: "Build context unavailable",
        suggestion: nil
    )

    #expect(!LSPCompletionPreflightGate.shouldQueryLSP(preflightError: error, context: typeContext))
}

@Test func preflightGateMarksMemberAccessAsPluginUnsatisfied() {
    let memberContext = LSPCompletionContext(prefix: "", isTypeContext: false, isMemberAccessContext: true)
    let typeContext = LSPCompletionContext(prefix: "In", isTypeContext: true, isMemberAccessContext: false)

    #expect(!LSPCompletionPreflightGate.pluginCanSatisfy(context: memberContext))
    #expect(LSPCompletionPreflightGate.pluginCanSatisfy(context: typeContext))
}

@Test func preflightGateSuppressesWhenPluginsCannotHelp() {
    #expect(
        LSPCompletionPreflightGate.blockedResult(pluginSuggestionCount: 0)
            == .suppressed
    )
    #expect(
        LSPCompletionPreflightGate.blockedResult(pluginSuggestionCount: 2)
            == .showPluginSuggestions(count: 2)
    )
}
