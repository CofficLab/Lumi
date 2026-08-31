import KernelCore

/// AppIconDesigner 宿主的插件工厂契约。
@MainActor
public protocol PluginFactory {
    func makePlugins() -> [any SuperPlugin]
}
