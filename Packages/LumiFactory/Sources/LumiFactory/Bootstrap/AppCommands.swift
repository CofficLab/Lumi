import LumiFactory
import LumiKernel
import SwiftUI

/// Application command menu.
///
/// Wires all command sub-groups together and injects the kernel where needed.
///
/// Uses `@CommandsBuilder` with a delayed command source that waits for the kernel
/// to be initialized before returning the actual commands.
public struct AppCommands: Commands {
    public init() {}

    public var body: some Commands {
        // Plugin-registered commands placed in the app menu (after About).
        CommandGroup(after: .appInfo) {
            PluginCommandContent(placement: .appMenu)
        }

        // Plugin-registered commands placed after the toolbar.
        CommandGroup(after: .toolbar) {
            PluginCommandContent(placement: .toolbar)
        }
    }
}

/// A `View`-based wrapper around dynamic plugin commands.
///
/// `CommandGroup`'s builder only accepts `View` values, so we wrap each
/// menu item in a `Button` view and return a single composed `some View`
/// (a stack of buttons). The wrapper observes the kernel's command service
/// via `CommandServiceObserver` so it can render items that registered
/// before the kernel became available.
private struct PluginCommandContent: View {
    let placement: CommandMenuPlacement
    @StateObject private var observer = CommandServiceObserver()

    var body: some View {
        // Stack the buttons vertically so each becomes a separate menu entry.
        // SwiftUI renders these as consecutive items inside the parent
        // `CommandGroup`.
        VStack(alignment: .leading, spacing: 0) {
            ForEach(observer.groups(for: placement)) { group in
                ForEach(group.items) { item in
                    Button(item.title) {
                        item.action()
                    }
                    .keyboardShortcutIfAvailable(item.shortcut, modifiers: item.modifiers)
                }
            }
        }
    }
}

/// Observes the command service from mainKernel.
@MainActor
private final class CommandServiceObserver: ObservableObject {
    @Published private(set) var appMenuGroups: [CommandMenuGroup] = []
    @Published private(set) var toolbarGroups: [CommandMenuGroup] = []

    private var pollingTask: Task<Void, Never>?

    init() {
        startPolling()
    }

    deinit {
        pollingTask?.cancel()
    }

    func groups(for placement: CommandMenuPlacement) -> [CommandMenuGroup] {
        switch placement {
        case .appMenu: return appMenuGroups
        case .toolbar: return toolbarGroups
        }
    }

    private func startPolling() {
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                updateGroups()
                if !appMenuGroups.isEmpty {
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }

    private func updateGroups() {
        guard let kernel = LumiFactory.mainKernel,
              let command = kernel.command else {
            return
        }
        appMenuGroups = command.allCommandGroups.filter { $0.placement == .appMenu }
        toolbarGroups = command.allCommandGroups.filter { $0.placement == .toolbar }
    }
}

// MARK: - Keyboard Shortcut Extension

private extension Button {
    func keyboardShortcutIfAvailable(
        _ key: KeyEquivalent?,
        modifiers: EventModifiers?
    ) -> some View {
        if let key, let modifiers {
            return self.keyboardShortcut(key, modifiers: modifiers).asAnyView()
        } else if let key {
            return self.keyboardShortcut(key).asAnyView()
        } else {
            return self.asAnyView()
        }
    }
}

private extension View {
    func asAnyView() -> AnyView {
        AnyView(self)
    }
}
