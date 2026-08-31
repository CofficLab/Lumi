import Combine
import KernelCore
import ProviderCommand
import SwiftUI

/// AppIconDesigner 的命令菜单宿主。
@MainActor
public struct AppCommands: Commands {
    private let kernel: KernelCoreContainer

    public init(kernel: KernelCoreContainer) {
        self.kernel = kernel
    }

    public var body: some Commands {
        CommandGroup(after: .appInfo) {
            PluginCommandContent(kernel: kernel, placement: .appMenu)
        }

        CommandGroup(after: .toolbar) {
            PluginCommandContent(kernel: kernel, placement: .toolbar)
        }
    }
}

private struct PluginCommandContent: View {
    @StateObject private var model: CommandGroupsModel

    init(kernel: KernelCoreContainer, placement: CommandMenuPlacement) {
        _model = StateObject(
            wrappedValue: CommandGroupsModel(
                provider: kernel.resolveProvider((any CommandProviding).self),
                placement: placement
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.groups) { group in
                ForEach(group.items) { item in
                    Button(item.title) {
                        item.action()
                    }
                    .keyboardShortcut(item.shortcut, modifiers: item.modifiers)
                }
            }
        }
    }
}

@MainActor
private final class CommandGroupsModel: ObservableObject {
    @Published private(set) var groups: [CommandMenuGroup]
    private let provider: (any CommandProviding)?
    private let placement: CommandMenuPlacement
    private var observer: (any CommandProvidingObserverHandle)?

    init(provider: (any CommandProviding)?, placement: CommandMenuPlacement) {
        self.provider = provider
        self.placement = placement
        groups = provider?.allCommandGroups.filter { $0.placement == placement } ?? []
        observer = provider?.addObserver { [weak self] _ in
            guard let self else { return }
            groups = self.provider?.allCommandGroups.filter { $0.placement == self.placement } ?? []
        }
    }
}

private extension View {
    @ViewBuilder
    func keyboardShortcut(_ key: Character?, modifiers: CommandModifiers) -> some View {
        if let key {
            keyboardShortcut(KeyEquivalent(key), modifiers: modifiers.swiftUIModifiers)
        } else {
            self
        }
    }
}

private extension CommandModifiers {
    var swiftUIModifiers: EventModifiers {
        var result: EventModifiers = []
        if contains(.command) { result.insert(.command) }
        if contains(.shift) { result.insert(.shift) }
        if contains(.option) { result.insert(.option) }
        if contains(.control) { result.insert(.control) }
        return result
    }
}
