# RClickPlugin

Customize Finder right-click menu actions

The Finder Sync extension source lives in `FinderExtension/` as part of this plugin. It remains a separate Xcode app-extension target because macOS Finder Sync requires an `.appex`; Xcode embeds the resulting `LumiFinder.appex` inside `Lumi.app/Contents/PlugIns/`.

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。
