import LumiUI

/// 将插件主题贡献登记到 ``LumiUIThemeRegistry``（Core ↔ LumiUI 桥梁）。
@MainActor
final class ThemeService {
    static let shared = ThemeService()

    private init() {}

    func syncFromPlugins(registry: LumiUIThemeRegistry = .shared) {
        let contributions = AppPluginVM.shared.getThemeContributions()
        do {
            try registry.replaceAll(contributions)
        } catch {
            fatalError(
                "Failed to register theme contributions: \(error). Enable at least one theme plugin."
            )
        }
    }
}
