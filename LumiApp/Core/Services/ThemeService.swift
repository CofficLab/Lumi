import LumiUI

/// 将插件主题贡献登记到 ``LumiUIThemeRegistry``（Core ↔ LumiUI 桥梁）。
@MainActor
final class ThemeService {
    static let shared = ThemeService()

    private init() {}

    func syncFromPlugins(registry: LumiUIThemeRegistry = .shared) {
        let contributions = AppPluginVM.shared.getThemeContributions()
        let themes = contributions.isEmpty ? [LumiUIThemeContribution.builtInFallback()] : contributions
        do {
            try registry.replaceAll(themes)
        } catch {
            try? registry.replaceAll([LumiUIThemeContribution.builtInFallback()])
        }
    }
}
