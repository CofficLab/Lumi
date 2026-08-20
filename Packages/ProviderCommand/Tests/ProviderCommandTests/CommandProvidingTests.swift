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

    private func group(id: String, title: String) -> CommandMenuGroup {
        CommandMenuGroup(
            id: id,
            name: id,
            items: [CommandItem(id: "\(id).item", title: title, action: {})],
            placement: .topLevelMenu
        )
    }
}
