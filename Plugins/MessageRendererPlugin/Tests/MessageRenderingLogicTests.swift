import Testing
import Foundation
import LumiKernel
@testable import MessageRendererPlugin

/// Unit tests for the pure logic helpers in MessageRendererPlugin.
@Suite struct MessageViewHelpersFormatModelNameTests {

    @Test func stripsTrailingNumericSegmentWhenMoreThanTwoParts() {
        // >2 parts, last part all digits → drop last segment.
        #expect(MessageViewHelpers.formatModelName("claude-3-5") == "claude-3")
        #expect(MessageViewHelpers.formatModelName("foo-1-2-3") == "foo-1-2")
    }

    @Test func keepsNameWhenTwoOrFewerParts() {
        #expect(MessageViewHelpers.formatModelName("gpt-4") == "gpt-4")
        #expect(MessageViewHelpers.formatModelName("o3") == "o3")
    }

    @Test func keepsNameWhenLastPartNotAllDigits() {
        #expect(MessageViewHelpers.formatModelName("gpt-4o-mini") == "gpt-4o-mini")
        #expect(MessageViewHelpers.formatModelName("claude-3-opus") == "claude-3-opus")
    }

    @Test func handlesEmptyAndSingleToken() {
        #expect(MessageViewHelpers.formatModelName("") == "")
        #expect(MessageViewHelpers.formatModelName("llama") == "llama")
    }
}

@Suite struct MessageViewHelpersFormatDurationTests {

    @Test func millisecondsForSubSecond() {
        #expect(MessageViewHelpers.formatDuration(0.5) == "500ms")
        #expect(MessageViewHelpers.formatDuration(0.05) == "50ms")
    }

    @Test func secondsWithOneDecimal() {
        #expect(MessageViewHelpers.formatDuration(1) == "1.0s")
        #expect(MessageViewHelpers.formatDuration(12.5) == "12.5s")
        #expect(MessageViewHelpers.formatDuration(59.9) == "59.9s")
    }

    @Test func minutesAndSecondsAtAndAboveSixty() {
        #expect(MessageViewHelpers.formatDuration(60) == "1m 0s")
        #expect(MessageViewHelpers.formatDuration(90) == "1m 30s")
        #expect(MessageViewHelpers.formatDuration(125) == "2m 5s")
    }

    @Test func zeroIsMilliseconds() {
        #expect(MessageViewHelpers.formatDuration(0) == "0ms")
    }
}

@Suite struct MessageViewHelpersFormatToolCallArgumentsTests {

    @Test func returnsNilForEmpty() {
        #expect(MessageViewHelpers.formatToolCallArguments("") == nil)
    }

    @Test func returnsNilForEmptyObject() {
        #expect(MessageViewHelpers.formatToolCallArguments("{}") == nil)
    }

    @Test func returnsNilForInvalidJSON() {
        #expect(MessageViewHelpers.formatToolCallArguments("not json") == nil)
        #expect(MessageViewHelpers.formatToolCallArguments("{broken") == nil)
    }

    @Test func prettyPrintsValidJSONWithSortedKeys() throws {
        let result = try #require(MessageViewHelpers.formatToolCallArguments("{\"b\":2,\"a\":1}"))
        // Sorted keys: a before b.
        let a = try #require(result.range(of: "\"a\""))
        let b = try #require(result.range(of: "\"b\""))
        #expect(a.lowerBound < b.lowerBound)
        #expect(result.contains("1"))
        #expect(result.contains("2"))
    }

    @Test func preservesNestedStructure() throws {
        let result = try #require(MessageViewHelpers.formatToolCallArguments("{\"path\":\"/a/b\",\"limit\":10}"))
        // Note: JSONSerialization escapes forward slashes by default (\/a\/b).
        #expect(result.contains("path"))
        #expect(result.contains("a"))
        #expect(result.contains("b"))
        #expect(result.contains("10"))
    }
}

@Suite struct MessageViewHelpersMetadataItemsTests {

    private func message(provider: String? = nil, model: String? = nil) -> LumiChatMessage {
        LumiChatMessage(conversationID: UUID(), role: .assistant, content: "hi",
                        providerID: provider, modelName: model)
    }

    @Test func emptyWhenNoProviderOrModel() {
        #expect(MessageViewHelpers.metadataItems(for: message()).isEmpty)
    }

    @Test func includesProviderAndFormattedModel() {
        let items = MessageViewHelpers.metadataItems(for: message(provider: "anthropic", model: "claude-3-5"))
        #expect(items == ["anthropic", "claude-3"])
    }

    @Test func omitsEmptyStrings() {
        let items = MessageViewHelpers.metadataItems(for: message(provider: "", model: ""))
        #expect(items.isEmpty)
    }

    @Test func providerOnly() {
        #expect(MessageViewHelpers.metadataItems(for: message(provider: "openai")) == ["openai"])
    }
}

@Suite struct MessageViewHelpersCopyContentTests {

    private func message(content: String, role: LumiChatMessageRole = .assistant,
                         model: String? = nil) -> LumiChatMessage {
        LumiChatMessage(conversationID: UUID(), role: role, content: content, modelName: model)
    }

    @Test func returnsContentWhenNonEmpty() {
        #expect(MessageViewHelpers.copyContent(for: message(content: "hello")) == "hello")
    }

    @Test func fallsBackToRawDescriptionWhenEmpty() {
        let m = message(content: "", model: "gpt-4")
        let raw = MessageViewHelpers.copyContent(for: m)
        #expect(raw.contains("role: assistant"))
        #expect(raw.contains("model: gpt-4"))
    }
}

@Suite struct ToolCallResultVisualStateTests {

    @Test func loadingWhenIsLoading() {
        #expect(ToolCallResultVisualState(result: nil, isLoading: true) == .loading)
        // Loading takes priority even if result is an error.
        let errorResult = LumiToolResult(content: "err", isError: true)
        #expect(ToolCallResultVisualState(result: errorResult, isLoading: true) == .loading)
    }

    @Test func failedWhenResultIsError() {
        let errorResult = LumiToolResult(content: "boom", isError: true)
        #expect(ToolCallResultVisualState(result: errorResult, isLoading: false) == .failed)
        #expect(ToolCallResultVisualState(result: errorResult, isLoading: false).isFailure)
    }

    @Test func completedWhenSuccessful() {
        let ok = LumiToolResult(content: "done", isError: false)
        #expect(ToolCallResultVisualState(result: ok, isLoading: false) == .completed)
    }

    @Test func completedWhenNoResultAndNotLoading() {
        #expect(ToolCallResultVisualState(result: nil, isLoading: false) == .completed)
    }

    @Test func systemImagePerState() {
        #expect(ToolCallResultVisualState.loading.systemImage == "hourglass")
        #expect(ToolCallResultVisualState.failed.systemImage == "exclamationmark.triangle.fill")
        #expect(ToolCallResultVisualState.completed.systemImage == "doc.text.magnifyingglass")
    }
}

@Suite struct ErrorTransportDetailsResolverTests {

    private static let separator = "\n\n--- Request / Response Details ---\n"

    private func errorMessage(
        content: String = "",
        rawErrorDetail: String? = nil,
        metadata: [String: String] = [:]
    ) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: UUID(),
            role: .error,
            content: content,
            isError: true,
            rawErrorDetail: rawErrorDetail,
            metadata: metadata
        )
    }

    @Test func splitsEmbeddedTransportDetailsFromLongestField() {
        let summary = #"HTTP 错误 (429): { "error": { "code": "429" } }"#
        let request = "Request URL: https://example.com"
        let full = summary + Self.separator + request

        let resolved = ErrorTransportDetailsResolver.resolve(
            for: errorMessage(content: full, rawErrorDetail: full)
        )

        #expect(resolved.displaySummary == summary)
        #expect(resolved.requestDetails == request)
        #expect(resolved.responseDetails == nil)
        #expect(resolved.hasTransportDetails)
    }

    @Test func prefersMetadataTransportDetails() {
        let resolved = ErrorTransportDetailsResolver.resolve(
            for: errorMessage(
                rawErrorDetail: "HTTP 401",
                metadata: [
                    "llm.transport.request": "Request URL: https://example.com",
                    "llm.transport.response": "Response Status: 401",
                ]
            )
        )

        #expect(resolved.displaySummary == "HTTP 401")
        #expect(resolved.requestDetails?.contains("Request URL") == true)
        #expect(resolved.responseDetails?.contains("Response Status") == true)
        #expect(resolved.hasTransportDetails)
    }

    @Test func keepsSummaryWhenNoTransportDetailsExist() {
        let summary = #"HTTP 错误 (403): forbidden"#
        let resolved = ErrorTransportDetailsResolver.resolve(
            for: errorMessage(content: summary, rawErrorDetail: summary)
        )

        #expect(resolved.displaySummary == summary)
        #expect(!resolved.hasTransportDetails)
    }
}
