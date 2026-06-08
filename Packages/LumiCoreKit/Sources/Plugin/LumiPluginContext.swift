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

public struct LumiPluginContext {
    public let activeSectionID: String
    public let activeSectionTitle: String
    public let dependencies: LumiPluginDependencies

    public init(
        activeSectionID: String,
        activeSectionTitle: String,
        dependencies: LumiPluginDependencies = LumiPluginDependencies()
    ) {
        self.activeSectionID = activeSectionID
        self.activeSectionTitle = activeSectionTitle
        self.dependencies = dependencies
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T? {
        dependencies.resolve(type)
    }
}
