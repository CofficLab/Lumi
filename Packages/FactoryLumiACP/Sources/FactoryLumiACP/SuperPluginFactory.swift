import KernelCore

/// ACP headless 宿主自己的插件装配契约。
@MainActor
public protocol PluginFactory {
    func makePlugins() -> [any SuperPlugin]
}
