import Combine
import LumiUI
import SwiftUI

/// 主题 ViewModel：委托 ``LumiUIThemeRegistry``，由 ``ThemeService`` 从插件同步贡献。
@MainActor
final class AppThemeVM: ObservableObject {

    private let registry: LumiUIThemeRegistry
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var themes: [LumiUIThemeContribution] = []

    @Published var currentThemeId: String {
        didSet {
            guard oldValue != currentThemeId else { return }
            applySelection(themeId: currentThemeId)
        }
    }

    var currentTheme: LumiUIThemeContribution? {
        themes.first(where: { $0.id == currentThemeId })
    }

    var activeChromeTheme: any LumiAppChromeTheme {
        requireSelectedContribution().chromeTheme
    }

    var activeEditorThemeId: String {
        requireSelectedContribution().editorThemeId
    }

    var activeFileIconTheme: (any LumiFileIconThemeContributor)? {
        currentTheme?.attachments.fileIconThemeContributor as? any LumiFileIconThemeContributor
    }

    init(registry: LumiUIThemeRegistry = .shared) {
        self.registry = registry
        ThemeService.shared.syncFromPlugins(registry: registry)
        let initialId = Self.requireSelectedId(registry: registry)
        self.themes = registry.themes
        self.currentThemeId = initialId
        bindRegistry()

        NotificationCenter.default.addObserver(
            forName: .pluginsDidLoad,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadThemes()
            }
        }
    }

    func reloadThemes() {
        ThemeService.shared.syncFromPlugins(registry: registry)
        syncPublishedStateFromRegistry(preserveSelection: true)
    }

    func selectTheme(_ themeId: String) {
        guard themes.contains(where: { $0.id == themeId }) else { return }
        if currentThemeId != themeId {
            currentThemeId = themeId
        }
    }

    static func editorThemeID(for themeId: String) -> String {
        let registry = LumiUIThemeRegistry.shared
        let themes = registry.themes
        if let match = themes.first(where: { $0.id == themeId }) {
            return match.editorThemeId
        }
        return (try? registry.defaultThemeId()) ?? themeId
    }

    static func currentEditorThemeId() -> String {
        let registry = LumiUIThemeRegistry.shared
        let themes = registry.themes
        if let savedThemeId = ThemeStatusBarPluginLocalStore.shared.loadSelectedThemeID(),
           let match = themes.first(where: { $0.id == savedThemeId }) {
            return match.editorThemeId
        }
        return (try? registry.defaultThemeId()) ?? ""
    }

    // MARK: - Private

    private func bindRegistry() {
        registry.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncPublishedStateFromRegistry(preserveSelection: true)
            }
            .store(in: &cancellables)
    }

    private func syncPublishedStateFromRegistry(preserveSelection: Bool) {
        themes = registry.themes
        guard let selectedId = registry.selectedThemeId else { return }
        if preserveSelection, themes.contains(where: { $0.id == currentThemeId }) {
            postThemeDidChange()
            return
        }
        if currentThemeId != selectedId {
            currentThemeId = selectedId
        } else {
            postThemeDidChange()
        }
    }

    private func applySelection(themeId: String) {
        do {
            try registry.select(themeId: themeId)
        } catch {
            return
        }
        postThemeDidChange()
    }

    private func requireSelectedContribution() -> LumiUIThemeContribution {
        if let contribution = currentTheme ?? themes.first {
            return contribution
        }
        fatalError(
            "No theme contributions from any plugin. Enable at least one theme plugin (e.g. ThemeLumiPlugin)."
        )
    }

    private static func requireSelectedId(registry: LumiUIThemeRegistry) -> String {
        guard let id = registry.selectedThemeId else {
            fatalError(
                "No theme contributions from any plugin. Enable at least one theme plugin (e.g. ThemeLumiPlugin)."
            )
        }
        return id
    }

    private func postThemeDidChange() {
        guard let selected = currentTheme ?? themes.first else { return }
        let colorScheme = SystemAppearanceResolver.effectiveColorScheme
        let editorThemeId = selected.chromeTheme.resolvedEditorThemeId(
            defaultEditorThemeId: selected.editorThemeId,
            colorScheme: colorScheme
        )
        NotificationCenter.default.post(
            name: .lumiThemeDidChange,
            object: nil,
            userInfo: [
                "themeId": selected.id,
                "editorThemeId": editorThemeId,
            ]
        )
    }
}

// MARK: - 预览

#Preview("AppThemeVM") {
    Text("AppThemeVM")
        .environmentObject(AppThemeVM())
}
