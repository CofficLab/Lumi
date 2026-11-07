@MainActor
public final class DefaultPromptSuggestionProvider: PromptSuggestionProviding {
    public private(set) var allSuggestions: [PromptSuggestion] = []
    private var observers: [WeakObserver] = []

    public init() {}

    @discardableResult
    public func addObserver(
        _ callback: @escaping (PromptSuggestionProvidingEvent) -> Void
    ) -> any PromptSuggestionProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    public func register(_ suggestion: PromptSuggestion) {
        var updated = allSuggestions.filter { $0.id != suggestion.id }
        updated.append(suggestion)
        updated.sort { $0.order < $1.order }
        guard updated != allSuggestions else { return }
        allSuggestions = updated
        notify(.suggestionsChanged(updated))
    }

    public func unregister(id: String) {
        let updated = allSuggestions.filter { $0.id != id }
        guard updated != allSuggestions else { return }
        allSuggestions = updated
        notify(.suggestionsChanged(updated))
    }

    public func removeAll() {
        guard !allSuggestions.isEmpty else { return }
        allSuggestions = []
        notify(.suggestionsChanged([]))
    }

    private func notify(_ event: PromptSuggestionProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        for observer in observers {
            observer.observer?.invoke(event)
        }
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private final class Observer: PromptSuggestionProvidingObserverHandle {
        private weak var owner: DefaultPromptSuggestionProvider?
        private let callback: (PromptSuggestionProvidingEvent) -> Void
        private var isCancelled = false

        init(
            owner: DefaultPromptSuggestionProvider,
            callback: @escaping (PromptSuggestionProvidingEvent) -> Void
        ) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: PromptSuggestionProvidingEvent) {
            guard !isCancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var observer: Observer?

        init(_ observer: Observer) {
            self.observer = observer
        }
    }
}
