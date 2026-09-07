import KernelCore
import ProviderContentView
import ProviderDocsView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderTheme
import ProviderToolbar

#if os(macOS)
import ProviderActivityBar
import ProviderCommand
import ProviderLogo
import ProviderRailView
#endif

/// BookletMaker 的最小 Provider 装配。
@MainActor
public struct DefaultProviderFactory: ProviderFactory {
    public init() {}

    public func makeStorageProvider() -> any StorageProviding {
        DefaultStorageProvider()
    }

    public func makeThemeProvider() -> any ThemeProviding {
        DefaultThemeProviding()
    }

    public func makeContentViewProvider() -> any ContentViewProviding {
        DefaultContentViewProviding()
    }

    public func makeDocsViewProvider() -> any DocsViewProviding {
        DefaultDocsViewProviding()
    }

    public func makeToolbarProvider() -> any ToolbarProviding {
        DefaultToolbarProviding()
    }

    public func makeRootViewProvider() -> any RootViewProviding {
        DefaultRootViewProvider()
    }

    public func makeSettingViewProvider() -> any SettingViewProviding {
        DefaultSettingViewProviding()
    }

    public func registerProviders(into kernel: KernelCoreContainer) throws {
        let storage = makeStorageProvider()
        try kernel.registerProvider((any StorageProviding).self, storage)

        // 插件启用状态仍由宿主统一持久化；BookletMaker 插件本身是 required，
        // 其他未来加入的插件则继续遵循 KernelCore 的普通策略。
        kernel.stateStore = PluginEnabledStateStore(
            pluginDirectory: storage.pluginDataDirectory(for: "PluginManager")
        )

        let theme = makeThemeProvider()
        if let defaultTheme = theme as? DefaultThemeProviding {
            defaultTheme.setStorageDirectory(
                storage.pluginDataDirectory(for: "ThemeManager")
            )
        }
        try kernel.registerProvider((any ThemeProviding).self, theme)

        try kernel.registerProvider((any ContentViewProviding).self, makeContentViewProvider())
        try kernel.registerProvider((any DocsViewProviding).self, makeDocsViewProvider())
        try kernel.registerProvider((any ToolbarProviding).self, makeToolbarProvider())
        try kernel.registerProvider((any RootViewProviding).self, makeRootViewProvider())
        try kernel.registerProvider((any SettingViewProviding).self, makeSettingViewProvider())

        #if os(macOS)
        try kernel.registerProvider((any LogoProviding).self, makeLogoProvider())
        try kernel.registerProvider((any ActivityBarProviding).self, makeActivityBarProvider())
        try kernel.registerProvider((any RailViewProviding).self, makeRailViewProvider())
        try kernel.registerProvider((any CommandProviding).self, makeCommandProvider())
        #endif
    }
}

#if os(macOS)
extension DefaultProviderFactory {
    public func makeLogoProvider() -> any LogoProviding {
        DefaultLogoProviding()
    }

    public func makeActivityBarProvider() -> any ActivityBarProviding {
        DefaultActivityBarProviding()
    }

    public func makeRailViewProvider() -> any RailViewProviding {
        DefaultRailViewProviding()
    }

    public func makeCommandProvider() -> any CommandProviding {
        DefaultCommandProviding()
    }
}
#endif
