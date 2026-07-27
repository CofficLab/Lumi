import LumiKernel
import SwiftUI

/// Application command menu.
///
/// Wires all command sub-groups together and injects the kernel where needed.
public struct AppCommands: Commands {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some Commands {
        // Chat commands: Cmd+Shift+L focus chat, Cmd+Return send, Esc stop
        ChatCommands()

        // Settings: Cmd+,
        SettingsCommand()

        // Window: Cmd+Shift+N new window
        WindowCommand()

        // Editor save: Cmd+S
        EditorSaveCommands()

        // Debug menu
        DebugCommand(kernel: kernel)

        // Check for updates (stub until UpdateService is restored)
        CheckForUpdatesCommand()

        // Plugin-registered command groups
        CommandGroup(after: .toolbar) {
            ForEach(kernel.command?.allCommandGroups ?? []) { group in
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
