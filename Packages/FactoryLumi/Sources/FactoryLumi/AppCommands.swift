import AppKit
import Combine
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
    private var lastSignature: String?

    init(provider: (any CommandProviding)?, placement: CommandMenuPlacement) {
        self.provider = provider
        self.placement = placement
        let groups = provider?.allCommandGroups.filter { $0.placement == placement } ?? []
        self.groups = groups
        self.lastSignature = commandGroupsSignature(groups)
        self.observer = provider?.addObserver { [weak self] _ in
            guard let self else { return }
            let groups = self.provider?.allCommandGroups.filter { $0.placement == self.placement } ?? []
            let signature = commandGroupsSignature(groups)
            guard signature != self.lastSignature else { return }
            self.groups = groups
            self.lastSignature = signature
        }
    }
}

@MainActor
private final class CommandMenuInstaller {
    static let shared = CommandMenuInstaller()

    private weak var commandProvider: (any CommandProviding)?
    private var commandProviderObserver: (any CommandProvidingObserverHandle)?
    private var pollingTask: Task<Void, Never>?
    private var installedMainMenu: NSMenu?
    private var installedMenus: [String: NSMenuItem] = [:]
    private var installedItems: [String: NSMenuItem] = [:]
    private var actionTargets: [String: CommandActionTarget] = [:]
    private var lastStructureSignature: String?

    func start(kernel: KernelCoreContainer) {
        guard pollingTask == nil else { return }

        commandProvider = kernel.resolveProvider((any CommandProviding).self)
        commandProviderObserver = commandProvider?.addObserver { [weak self] _ in
            self?.synchronizeIfPossible()
        }

        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.synchronizeIfPossible()
                if NSApplication.shared.mainMenu == nil {
                    try? await Task.sleep(for: .milliseconds(100))
                    continue
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func synchronizeIfPossible() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        if installedMainMenu !== mainMenu {
            installedMainMenu = mainMenu
            // SwiftUI may replace the NSMenu instance when its command tree
            // changes. Keep our menu items/targets so the next synchronization
            // can attach them to the new menu without first removing them from
            // the visible menu.
            lastStructureSignature = nil
        }

        let groups = commandProvider?.allCommandGroups
            .filter { $0.placement == .topLevelMenu } ?? []
        let structureSignature = commandGroupsStructureSignature(groups)
        let wasEvicted = installedMenus.values.contains { installed in
            !mainMenu.items.contains { $0 === installed }
        }

        if structureSignature != lastStructureSignature || wasEvicted {
            synchronize(in: mainMenu, groups: groups)
            lastStructureSignature = structureSignature
        } else {
            updateStates(for: groups)
        }
    }

    private func synchronize(in mainMenu: NSMenu, groups: [CommandMenuGroup]) {
        let groupIDs = Set(groups.map(\.id))
        let removedGroups = installedMenus.filter { !groupIDs.contains($0.key) }
        for (groupID, menuItem) in removedGroups {
            if mainMenu.items.contains(where: { $0 === menuItem }) {
                mainMenu.removeItem(menuItem)
            }
            installedMenus.removeValue(forKey: groupID)
            removeInstalledItems(for: groupID)
        }

        for group in groups {
            let rootItem = installedMenus[group.id]
                ?? NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
            rootItem.title = group.name
            let submenu = rootItem.submenu ?? NSMenu(title: group.name)
            submenu.title = group.name
            removeInstalledItems(for: group.id)
            submenu.removeAllItems()

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
                let itemKey = installedItemKey(groupID: group.id, itemID: item.id)
                installedItems[itemKey] = child
                actionTargets[itemKey] = target
            }

            rootItem.submenu = submenu
            if !mainMenu.items.contains(where: { $0 === rootItem }) {
                mainMenu.addItem(rootItem)
            }
            installedMenus[group.id] = rootItem
        }

        updateStates(for: groups)
    }

    private func updateStates(for groups: [CommandMenuGroup]) {
        for group in groups {
            for item in group.items {
                let key = installedItemKey(groupID: group.id, itemID: item.id)
                installedItems[key]?.state = item.state == .on ? .on : .off
            }
        }
    }

    private func removeInstalledItems(for groupID: String) {
        let prefix = "\(groupID)."
        installedItems.keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { installedItems.removeValue(forKey: $0) }
        actionTargets.keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { actionTargets.removeValue(forKey: $0) }
    }

    private func installedItemKey(groupID: String, itemID: String) -> String {
        "\(groupID).\(itemID)"
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

@MainActor
private func commandGroupsStructureSignature(_ groups: [CommandMenuGroup]) -> String {
    groups.map { group in
        let items = group.items.map { item in
            "\(item.id)=\(item.title)=\(item.shortcut.map(String.init) ?? "")=\(item.modifiers.rawValue)"
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
