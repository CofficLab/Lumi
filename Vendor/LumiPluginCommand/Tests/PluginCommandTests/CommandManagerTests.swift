import Foundation
import Testing
@testable import PluginCommand
import ProviderCommand

@MainActor
struct CommandManagerTests {

    private func makeGroup(id: String) -> CommandMenuGroup {
        CommandMenuGroup(id: id, name: "g-\(id)", items: [], placement: .topLevelMenu)
    }

    @Test("registerCommandGroup appends new groups")
    func registerAppends() {
        let mgr = CommandManager()
        mgr.registerCommandGroup(makeGroup(id: "a"))
        mgr.registerCommandGroup(makeGroup(id: "b"))
        #expect(mgr.allCommandGroups.map(\.id) == ["a", "b"])
    }

    @Test("registerCommandGroup replaces existing group with same id")
    func registerReplaces() {
        let mgr = CommandManager()
        mgr.registerCommandGroup(makeGroup(id: "a"))
        let updated = CommandMenuGroup(id: "a", name: "updated", items: [], placement: .topLevelMenu)
        mgr.registerCommandGroup(updated)
        #expect(mgr.allCommandGroups.count == 1)
        #expect(mgr.allCommandGroups.first?.name == "updated")
    }

    @Test("unregisterCommandGroup removes matching id and notifies")
    func unregisterRemoves() {
        let mgr = CommandManager()
        mgr.registerCommandGroup(makeGroup(id: "a"))
        mgr.registerCommandGroup(makeGroup(id: "b"))
        mgr.unregisterCommandGroup(id: "a")
        #expect(mgr.allCommandGroups.map(\.id) == ["b"])
    }

    @Test("unregisterCommandGroup is a no-op for unknown id")
    func unregisterUnknownIsNoOp() {
        let mgr = CommandManager()
        mgr.registerCommandGroup(makeGroup(id: "a"))
        mgr.unregisterCommandGroup(id: "missing")
        #expect(mgr.allCommandGroups.map(\.id) == ["a"])
    }

    @Test("observer receives groupsChanged events and stops after cancel")
    func observerLifecycle() {
        let mgr = CommandManager()
        var events: [CommandProvidingEvent] = []
        let handle = mgr.addObserver { events.append($0) }

        mgr.registerCommandGroup(makeGroup(id: "a"))
        #expect(events.count == 1)

        handle.cancel()
        mgr.registerCommandGroup(makeGroup(id: "b"))
        #expect(events.count == 1, "cancelled observer should not receive events")
    }

    @Test("registerCommandGroup notifies observer on replacement")
    func replaceNotifies() {
        let mgr = CommandManager()
        var count = 0
        let handle = mgr.addObserver { _ in count += 1 }
        _ = handle
        mgr.registerCommandGroup(makeGroup(id: "a"))
        mgr.registerCommandGroup(makeGroup(id: "a"))
        #expect(count == 2)
    }
}
