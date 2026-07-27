import Foundation

/// 插件依赖注入容器
///
/// 旧版 `LumiPluginDependencies` 的等价类型,在新 LumiKernel 体系下继续使用。
/// 插件在构建上下文时,把所有需要的服务注册到本容器,后续通过 `resolve(_:)`
/// 取出;类型擦除为 `ObjectIdentifier`,因此支持任意类型作为 key。
@MainActor
public struct LumiPluginDependencies {
    private var values: [ObjectIdentifier: Any]

    public init() {
        self.values = [:]
    }

    public init(_ configure: (inout LumiPluginDependencies) -> Void) {
        self.init()
        configure(&self)
    }

    public mutating func register<T>(_ type: T.Type, _ value: T) {
        values[ObjectIdentifier(type)] = value
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T? {
        values[ObjectIdentifier(type)] as? T
    }
}
