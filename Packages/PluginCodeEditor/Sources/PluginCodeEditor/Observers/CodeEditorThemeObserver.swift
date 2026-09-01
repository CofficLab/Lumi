import AppKit
import EditorService
import Foundation
import ProviderTheme
import SwiftUI

/// 将 `ThemeProviding` 的当前主题同步到 `EditorService`。
///
/// 主题 Provider 是应用主题的唯一来源；编辑器只消费注册到
/// `EditorExtensionRegistry` 的 `SuperEditorThemeContributor`。监听器负责两者
/// 之间的适配和生命周期管理，避免 EditorService 反向依赖 ProviderTheme。
@MainActor
final class CodeEditorThemeObserver {
    private weak var editor: EditorService?
    private weak var theme: (any ThemeProviding)?
    private var themeObserver: (any ThemeProvidingObserverHandle)?
    private var systemAppearanceObserver: NSObjectProtocol?
    private var registeredThemeIDs = Set<String>()

    init(theme: any ThemeProviding, editor: EditorService) {
        self.theme = theme
        self.editor = editor
    }

    func start() {
        guard themeObserver == nil, let theme else { return }

        themeObserver = theme.addObserver { [weak self] _ in
            self?.syncCurrentThemes()
        }
        systemAppearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncCurrentThemes()
            }
        }
        syncCurrentThemes()
    }

    func cancel() {
        themeObserver?.cancel()
        themeObserver = nil

        if let systemAppearanceObserver {
            DistributedNotificationCenter.default().removeObserver(systemAppearanceObserver)
            self.systemAppearanceObserver = nil
        }

        if let editor {
            for id in registeredThemeIDs {
                editor.editorExtensions.unregisterThemeContributor(id: id)
            }
            editor.theme.syncInitialThemeFromExternal("xcode-dark")
        }
        registeredThemeIDs.removeAll()
    }

    private func syncCurrentThemes() {
        guard let theme, let editor else { return }

        let contributors: [PaletteSyntaxThemeContributor] = theme.themes.flatMap { appTheme in
            CodeEditorThemeAdapter.palettes(for: appTheme).map { scheme, palette in
                let id = CodeEditorThemeAdapter.editorThemeID(for: appTheme, colorScheme: scheme)
                return PaletteSyntaxThemeContributor(
                    id: id,
                    displayName: appTheme.displayName,
                    isDark: scheme == .dark,
                    palette: palette
                )
            }
        }
        let nextIDs = Set(contributors.map { $0.id })

        for staleID in registeredThemeIDs.subtracting(nextIDs) {
            editor.editorExtensions.unregisterThemeContributor(id: staleID)
        }
        for contributor in contributors {
            editor.editorExtensions.registerOrReplaceThemeContributor(contributor)
        }
        registeredThemeIDs = nextIDs

        guard let selected = theme.selectedTheme else {
            editor.theme.syncInitialThemeFromExternal("xcode-dark")
            return
        }
        let activeScheme = CodeEditorThemeAdapter.colorScheme(for: selected)
        let activeID = CodeEditorThemeAdapter.editorThemeID(
            for: selected,
            colorScheme: activeScheme
        )
        editor.theme.syncInitialThemeFromExternal(activeID)
    }
}
