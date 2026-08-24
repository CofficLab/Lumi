import AppKit
import KernelCore
import ProviderCommand
import SwiftUI

/// macOS system-menu host for commands contributed through `CommandProviding`.
///
/// Static placements use SwiftUI `CommandGroup`; a dynamic number of standalone
/// top-level menus is installed through AppKit because `CommandsBuilder` cannot
/// build `CommandMenu` values from `ForEach`.
public struct AppCommands: Commands {
    private let kernel: KernelCoreContainer
    private let checkForUpdates: (@MainActor @Sendable () -> Void)?

    public init(
        kernel: KernelCoreContainer,
        checkForUpdates: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.kernel = kernel
        self.checkForUpdates = checkForUpdates
        CommandMenuInstaller.shared.start(kernel: kernel)
    }

    public var body: some Commands {
        CommandGroup(after: .appInfo) {
            if let checkForUpdates {
                Button("Check for Updates...") {
                    checkForUpdates()
                }
            }
            PluginCommandContent(kernel: kernel, placement: .appMenu)
        }

        CommandGroup(after: .toolbar) {
            PluginCommandContent(kernel: kernel, placement: .toolbar)
        }
    }
}

private struct PluginCommandContent: View {
    let kernel: KernelCoreContainer
    let placement: CommandMenuPlacement

    @State private var groups: [CommandMenuGroup] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groups) { group in
                ForEach(group.items) { item in
                    Button(item.title) {
                        item.action()
                    }
                    .keyboardShortcut(item.shortcut, modifiers: item.modifiers)
                }
            }
        }
        .task {
            while !Task.isCancelled {
                groups = kernel.resolveProvider((any CommandProviding).self)?
                    .allCommandGroups
                    .filter { $0.placement == placement } ?? []
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
}

@MainActor
private final class CommandMenuInstaller {
    static let shared = CommandMenuInstaller()

    private weak var kernel: KernelCoreContainer?
    private var pollingTask: Task<Void, Never>?
    private var installedMainMenu: NSMenu?
    private var installedMenus: [String: NSMenuItem] = [:]
    private var actionTargets: [String: CommandActionTarget] = [:]
    private var lastSignature: String?

    func start(kernel: KernelCoreContainer) {
        self.kernel = kernel
        guard pollingTask == nil else { return }

        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self,
                      let kernel = self.kernel,
                      let mainMenu = NSApplication.shared.mainMenu else {
                    try? await Task.sleep(for: .milliseconds(100))
                    continue
                }

                if installedMainMenu !== mainMenu {
                    installedMainMenu = mainMenu
                    installedMenus.removeAll()
                    actionTargets.removeAll()
                    lastSignature = nil
                }

                let groups = kernel.resolveProvider((any CommandProviding).self)?
                    .allCommandGroups
                    .filter { $0.placement == .topLevelMenu } ?? []
                let signature = commandGroupsSignature(groups)
                let wasEvicted = installedMenus.values.contains { installed in
                    !mainMenu.items.contains { $0 === installed }
                }

                if signature != lastSignature || wasEvicted {
                    rebuild(in: mainMenu, groups: groups)
                    lastSignature = signature
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func rebuild(in mainMenu: NSMenu, groups: [CommandMenuGroup]) {
        for menuItem in installedMenus.values where mainMenu.items.contains(where: { $0 === menuItem }) {
            mainMenu.removeItem(menuItem)
        }
        installedMenus.removeAll()
        actionTargets.removeAll()

        for group in groups {
            let rootItem = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: group.name)

            for item in group.items {
                let target = CommandActionTarget(action: item.action)
                let child = NSMenuItem(
                    title: item.title,
                    action: #selector(CommandActionTarget.performAction(_:)),
                    keyEquivalent: item.shortcut.map(String.init) ?? ""
                )
                child.keyEquivalentModifierMask = item.modifiers.appKitModifiers
                child.state = item.state == .on ? .on : .off
                child.target = target
                submenu.addItem(child)
                actionTargets["\(group.id).\(item.id)"] = target
            }

            rootItem.submenu = submenu
            mainMenu.addItem(rootItem)
            installedMenus[group.id] = rootItem
        }
    }
}

@MainActor
private final class CommandActionTarget: NSObject {
    private let action: @MainActor @Sendable () -> Void

    init(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    @objc func performAction(_ sender: NSMenuItem) {
        action()
    }
}

@MainActor
private func commandGroupsSignature(_ groups: [CommandMenuGroup]) -> String {
    groups.map { group in
        let items = group.items.map { item in
            "\(item.id)=\(item.title)=\(item.shortcut.map(String.init) ?? "")=\(item.modifiers.rawValue)=\(item.state)"
        }.joined(separator: ";")
        return "\(group.id)=\(group.name)=[\(items)]"
    }.joined(separator: "|")
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

    var appKitModifiers: NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        if contains(.command) { result.insert(.command) }
        if contains(.shift) { result.insert(.shift) }
        if contains(.option) { result.insert(.option) }
        if contains(.control) { result.insert(.control) }
        return result
    }
}
