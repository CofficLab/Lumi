import AppKit
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
    public init() {
        CommandMenuInstaller.shared.start()
    }

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
                PluginCommandItems(group: group)
            }
        }
    }
}

private struct PluginCommandItems: View {
    let group: CommandMenuGroup

    var body: some View {
        ForEach(group.items) { item in
            Button(item.title) {
                item.action()
            }
            .keyboardShortcutIfAvailable(item.shortcut, modifiers: item.modifiers)
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
        case .topLevelMenu: return []
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

/// Installs plugin-defined top-level menus in the application's main menu.
/// SwiftUI's `CommandsBuilder` cannot create a dynamic number of `CommandMenu`
/// values, so the factory bridges this one dynamic placement to AppKit.
@MainActor
private final class CommandMenuInstaller {
    static let shared = CommandMenuInstaller()

    private var startTask: Task<Void, Never>?
    private var installedMenus: [String: NSMenuItem] = [:]
    private var actionTargets: [String: CommandActionTarget] = [:]
    // Keep the menu alive while comparing it between polling iterations. A
    // weak reference can become nil for an AppKit menu owned by SwiftUI,
    // which would incorrectly force a full rebuild on every iteration.
    private var installedMainMenu: NSMenu?
    private var lastGroupsSignature: String?

    func start() {
        guard startTask == nil else { return }

        startTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self,
                      let kernel = LumiFactory.mainKernel,
                      let command = kernel.command,
                      let mainMenu = NSApplication.shared.mainMenu else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }

                if self.installedMainMenu !== mainMenu {
                    self.installedMainMenu = mainMenu
                    self.installedMenus.removeAll()
                    self.actionTargets.removeAll()
                    self.lastGroupsSignature = nil
                }

                let groups = command.allCommandGroups
                let signature = self.signature(for: groups)
                if self.lastGroupsSignature != signature {
                    self.rebuild(in: mainMenu, groups: groups)
                    self.lastGroupsSignature = signature
                }
                // SwiftUI 的默认菜单(File/Edit/View/Window/Help)标题走框架自带
                // 的本地化路径,不会读我们的 Localizable.xcstrings。这里在主菜单
                // 就绪后把它们的 title 改成走 LumiLocalization 的本地化版本,
                // 与"调试 / 主题"等自定义菜单一致。
                self.localizeStandardMenuTitles(in: mainMenu)
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func signature(for groups: [CommandMenuGroup]) -> String {
        groups.map { group in
            let items = group.items.map { item in
                let stateStr = String(describing: item.state)
                return "\(item.id)=\(item.title)=\(String(describing: item.shortcut))=\(String(describing: item.modifiers))=\(stateStr)"
            }.joined(separator: ";")
            return "\(group.id)=\(group.name)=\(group.placement.rawValue)=[\(items)]"
        }.joined(separator: "|")
    }

    private func rebuild(in mainMenu: NSMenu, groups: [CommandMenuGroup]) {
        let topLevelGroups = groups.filter { $0.placement == .topLevelMenu }
        let activeIDs = Set(topLevelGroups.map(\.id))

        let removedIDs = installedMenus.keys.filter { !activeIDs.contains($0) }
        for id in removedIDs {
            guard let menuItem = installedMenus[id] else { continue }
            mainMenu.removeItem(menuItem)
            installedMenus.removeValue(forKey: id)
            actionTargets.removeValue(forKey: id)
        }

        for group in topLevelGroups {
            let menuItem = installedMenus[group.id] ?? NSMenuItem()
            menuItem.title = group.name
            let submenu = NSMenu(title: group.name)
            actionTargets = actionTargets.filter { !$0.key.hasPrefix("\(group.id).") }

            for item in group.items {
                let target = CommandActionTarget(action: item.action)
                let menuItem = NSMenuItem(
                    title: item.title,
                    action: #selector(CommandActionTarget.performAction(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = target
                menuItem.state = item.state == .on ? .on : .off
                submenu.addItem(menuItem)
                actionTargets["\(group.id).\(item.id)"] = target
            }

            menuItem.submenu = submenu
            if installedMenus[group.id] == nil {
                mainMenu.addItem(menuItem)
                installedMenus[group.id] = menuItem
            }
        }
    }

    /// 把 SwiftUI 默认菜单(File / Edit / View / Window / Help)替换为中文标题。
    /// SwiftUI 会持续重置其管控的 NSMenuItem.title,因此不能只设 title,
    /// 必须创建全新的 NSMenuItem 脱离 SwiftUI 管控,把原 submenu 转移过去。
    private func localizeStandardMenuTitles(in mainMenu: NSMenu) {
        let translations: [String: String] = [
            "File": "文件", "Edit": "编辑", "View": "视图",
            "Window": "窗口", "Help": "帮助",
        ]
        var toReplace: [(Int, String)] = []
        for (index, item) in mainMenu.items.enumerated() {
            if let localized = translations[item.title] {
                toReplace.append((index, localized))
            }
        }
        for (index, localized) in toReplace.reversed() {
            let oldItem = mainMenu.items[index]
            let newItem = NSMenuItem(title: localized, action: nil, keyEquivalent: "")
            newItem.submenu = oldItem.submenu
            mainMenu.removeItem(oldItem)
            mainMenu.insertItem(newItem, at: index)
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
