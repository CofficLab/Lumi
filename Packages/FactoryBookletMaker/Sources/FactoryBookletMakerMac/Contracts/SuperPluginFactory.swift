import KernelCore

/// BookletMaker 宿主的插件工厂契约。
@MainActor
public protocol PluginFactory {
    /// 产出本宿主实际需要启动的插件。
    func makePlugins() -> [any SuperPlugin]
}
