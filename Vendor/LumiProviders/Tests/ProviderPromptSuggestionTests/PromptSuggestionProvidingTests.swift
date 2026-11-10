import Testing

@testable import ProviderPromptSuggestion

@Suite("PromptSuggestionProviding")
@MainActor
struct PromptSuggestionProvidingTests {
    @Test("建议变化通过类型化事件发送，并支持取消")
    func observerReceivesChangesAndCanCancel() {
        let provider = DefaultPromptSuggestionProvider()
        var snapshots: [[PromptSuggestion]] = []
        let observer = provider.addObserver { event in
            guard case let .suggestionsChanged(suggestions) = event else { return }
            snapshots.append(suggestions)
        }

        let first = PromptSuggestion(id: "first", title: "First", order: 20)
        let second = PromptSuggestion(id: "second", title: "Second", order: 10)
        provider.register(first)
        provider.register(second)

        #expect(snapshots == [[first], [second, first]])

        observer.cancel()
        provider.unregister(id: "first")
        #expect(snapshots == [[first], [second, first]])
    }

    @Test("重复注册相同建议和清空空列表不会重复通知")
    func unchangedMutationsDoNotNotify() {
        let provider = DefaultPromptSuggestionProvider()
        var changeCount = 0
        let observer = provider.addObserver { _ in changeCount += 1 }

        let suggestion = PromptSuggestion(id: "same", title: "Same")
        provider.register(suggestion)
        provider.register(suggestion)
        provider.removeAll()
        provider.removeAll()

        #expect(changeCount == 2)
        observer.cancel()
    }
}
