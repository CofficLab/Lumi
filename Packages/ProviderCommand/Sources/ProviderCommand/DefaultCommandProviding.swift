import Foundation

@MainActor
public final class DefaultCommandProviding: CommandProviding {
    public private(set) var allCommandGroups: [CommandMenuGroup] = []

    public init() {}

    public func registerCommandGroup(_ group: CommandMenuGroup) {
        if let index = allCommandGroups.firstIndex(where: { $0.id == group.id }) {
            allCommandGroups[index] = group
        } else {
            allCommandGroups.append(group)
        }
    }

    public func unregisterCommandGroup(id: String) {
        allCommandGroups.removeAll { $0.id == id }
    }
}
