import SwiftUI

/// 主题登记中心：排序、选择、同步外壳与组件主题。
@MainActor
public final class LumiUIThemeRegistry: ObservableObject {
    public static let shared = LumiUIThemeRegistry()

    @Published public private(set) var catalog: ThemeCatalog?

    @Published public private(set) var chromeTheme: any LumiAppChromeTheme = UnconfiguredChromeTheme()

    @Published public private(set) var uiTheme: any LumiUITheme = LumiDefaultTheme()

    /// 当前系统有效明暗；`.system` 主题下随 macOS 外观变化更新，供 SwiftUI 触发重绘。
    @Published public private(set) var systemColorScheme: ColorScheme = SystemAppearanceResolver.effectiveColorScheme

    /// 系统外观变化且当前主题为 `.system` 时调用（例如同步编辑器语法主题）。
    public var onSystemAppearanceDidChange: (() -> Void)?

    public init() {
        _ = SystemAppearanceObserver.shared
    }

    public var themes: [LumiUIThemeContribution] {
        catalog?.themes ?? []
    }

    public var selectedContribution: LumiUIThemeContribution? {
        catalog?.selected
    }

    public var selectedThemeId: String? {
        catalog?.selectedId
    }

    public func defaultThemeId() throws -> String {
        guard let id = catalog?.defaultThemeId else {
            throw ThemeError.noThemesRegistered
        }
        return id
    }

    /// 用新的贡献列表替换目录；空列表或重复 id 时抛出 ``ThemeError``。
    public func replaceAll(_ contributions: [LumiUIThemeContribution]) throws {
        let sorted = try sortedUnique(contributions)
        let previousId = catalog?.selectedId
        let selectedId: String
        if let previousId, sorted.contains(where: { $0.id == previousId }) {
            selectedId = previousId
        } else {
            guard let firstId = sorted.first?.id else {
                throw ThemeError.noThemesRegistered
            }
            selectedId = firstId
        }
        catalog = ThemeCatalog(themes: sorted, selectedId: selectedId)
        try applySelection()
    }

    /// 选中指定主题 id。
    public func select(themeId: String) throws {
        guard let catalog else {
            throw ThemeError.noThemesRegistered
        }
        guard catalog.themes.contains(where: { $0.id == themeId }) else {
            throw ThemeError.unknownThemeId(themeId)
        }
        self.catalog = ThemeCatalog(themes: catalog.themes, selectedId: themeId)
        try applySelection()
    }

    public func resolvedEditorThemeId(colorScheme: ColorScheme) -> String? {
        resolvedEditorSyntax(colorScheme: colorScheme)?.themeId
    }

    /// 由系统外观观察者或 ``ThemeWindowAppearanceBridge`` 调用。
    public func handleSystemAppearanceDidChange() {
        guard chromeTheme.followsSystemAppearance else { return }
        Task { @MainActor in
            let scheme = SystemAppearanceResolver.effectiveColorScheme
            ResolvedSystemColorScheme.current = scheme
            systemColorScheme = scheme
            republishCurrentUITheme()
            onSystemAppearanceDidChange?()
            ThemeWindowAppearanceSync.syncAllWindows()
        }
    }

    public func resolvedEditorSyntax(colorScheme: ColorScheme) -> ResolvedEditorSyntax? {
        guard let contribution = selectedContribution else { return nil }
        let chrome = contribution.chromeTheme
        let themeId = chrome.resolvedEditorThemeId(
            defaultEditorThemeId: contribution.editorThemeId,
            colorScheme: colorScheme
        )
        let palette = chrome.editorSyntaxPalette(colorScheme: colorScheme)
        let isDark: Bool = {
            switch chrome.appearanceKind {
            case .dark: return true
            case .light: return false
            case .system: return colorScheme == .dark
            }
        }()
        return ResolvedEditorSyntax(themeId: themeId, palette: palette, isDark: isDark)
    }

    // MARK: - Private

    private func sortedUnique(_ contributions: [LumiUIThemeContribution]) throws -> [LumiUIThemeContribution] {
        guard !contributions.isEmpty else {
            throw ThemeError.noThemesRegistered
        }
        var seen = Set<String>()
        for contribution in contributions {
            if seen.contains(contribution.id) {
                throw ThemeError.duplicateThemeId(contribution.id)
            }
            seen.insert(contribution.id)
        }
        return contributions.sorted { $0.sortKey < $1.sortKey }
    }

    private func applySelection() throws {
        guard let contribution = catalog?.selected else {
            throw ThemeError.noThemesRegistered
        }
        let chrome = contribution.chromeTheme
        chromeTheme = chrome
        syncResolvedColorScheme(for: chrome)
        ActiveChromeTheme.current = chrome
        republishCurrentUITheme(from: contribution)
    }

    private func syncResolvedColorScheme(for chrome: any LumiAppChromeTheme) {
        switch chrome.appearanceKind {
        case .system:
            let scheme = SystemAppearanceResolver.effectiveColorScheme
            ResolvedSystemColorScheme.current = scheme
            systemColorScheme = scheme
        case .dark:
            ResolvedSystemColorScheme.current = .dark
        case .light:
            ResolvedSystemColorScheme.current = .light
        }
    }

    private func republishCurrentUITheme(from contribution: LumiUIThemeContribution? = nil) {
        let source = contribution ?? selectedContribution
        guard let source else { return }
        let resolvedUI = source.uiTheme ?? ChromeToUIThemeAdapter(chrome: source.chromeTheme)
        Task { @MainActor in
            self.uiTheme = resolvedUI
            LumiUIThemeStore.shared.setTheme(resolvedUI)
            ThemeWindowAppearanceSync.syncAllWindows()
        }
    }
}
