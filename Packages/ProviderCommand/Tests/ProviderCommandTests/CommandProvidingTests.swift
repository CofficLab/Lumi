import Testing
@testable import ProviderCommand

@MainActor
struct CommandProvidingTests {
    @Test("command groups preserve order and replace matching IDs in place")
    func registrationOrderAndReplacement() {
        let provider = DefaultCommandProviding()
        provider.registerCommandGroup(group(id: "first", title: "One"))
        provider.registerCommandGroup(group(id: "second", title: "Two"))
        provider.registerCommandGroup(group(id: "first", title: "Updated"))

        #expect(provider.allCommandGroups.map(\.id) == ["first", "second"])
        #expect(provider.allCommandGroups.first?.items.first?.title == "Updated")

        provider.unregisterCommandGroup(id: "first")
        #expect(provider.allCommandGroups.map(\.id) == ["second"])
    }

    @Test("command state providers are evaluated live")
    func liveState() {
        final class Selection: @unchecked Sendable {
            var isSelected = false
        }
        let selection = Selection()
        let item = CommandItem(
            id: "theme",
            title: "Theme",
            stateProvider: { selection.isSelected ? .on : .off },
            action: {}
        )

        #expect(item.state == .off)
        selection.isSelected = true
        #expect(item.state == .on)
    }

    @Test("command provider emits precise group events and supports cancellation")
    func observerLifecycle() {
        let provider = DefaultCommandProviding()
        var eventCount = 0
        let handle = provider.addObserver { event in
            if case .groupsChanged = event {
                eventCount += 1
            }
        }

        provider.registerCommandGroup(group(id: "first", title: "One"))
        provider.registerCommandGroup(group(id: "first", title: "Updated"))
        provider.unregisterCommandGroup(id: "first")
        provider.unregisterCommandGroup(id: "missing")
        #expect(eventCount == 3)

        handle.cancel()
        provider.registerCommandGroup(group(id: "second", title: "Two"))
        #expect(eventCount == 3)
    }

    @Test("cancelling an observer twice is safe")
    func doubleCancelIsIdempotent() {
        let provider = DefaultCommandProviding()
        var eventCount = 0
        let handle = provider.addObserver { event in
            if case .groupsChanged = event { eventCount += 1 }
        }

        handle.cancel()
        handle.cancel()  // must not crash
        provider.registerCommandGroup(group(id: "x", title: "X"))
        #expect(eventCount == 0)
    }

    @Test("deallocated observers are pruned without affecting live ones")
    func deallocatedObserverIsPruned() {
        let provider = DefaultCommandProviding()
        var liveCount = 0
        let liveHandle = provider.addObserver { event in
            if case .groupsChanged = event { liveCount += 1 }
        }

        // Dropped immediately; provider holds only a weak reference.
        do {
            let transient = provider.addObserver { _ in }
            _ = transient
        }

        provider.registerCommandGroup(group(id: "a", title: "A"))
        provider.registerCommandGroup(group(id: "b", title: "B"))

        #expect(liveCount == 2)
    }

    private func group(id: String, title: String) -> CommandMenuGroup {
        CommandMenuGroup(
            id: id,
            name: id,
            items: [CommandItem(id: "\(id).item", title: title, action: {})],
            placement: .topLevelMenu
        )
    }
}
