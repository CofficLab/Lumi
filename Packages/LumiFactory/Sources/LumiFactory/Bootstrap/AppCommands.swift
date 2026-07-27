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
        // Plugin-registered commands placed in the app menu (after About)
        // Note: Settings, Window, Debug commands are registered via CommandPlugin in onBoot
        CommandGroup(after: .appInfo) {
            ForEach(kernel.command?.allCommandGroups.filter { $0.placement == .appMenu } ?? []) { group in
                ForEach(group.items) { item in
                    Button(item.title) {
                        item.action()
                    }
                    .keyboardShortcutIfAvailable(item.shortcut, modifiers: item.modifiers)
                }
            }
        }

        // Plugin-registered commands placed after the toolbar
        CommandGroup(after: .toolbar) {
            ForEach(kernel.command?.allCommandGroups.filter { $0.placement == .toolbar } ?? []) { group in
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
