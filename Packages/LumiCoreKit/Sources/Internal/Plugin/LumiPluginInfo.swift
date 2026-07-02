public struct LumiPluginInfo: Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let description: String
    public let order: Int

    public init(id: String, displayName: String, description: String = "", order: Int = 1_000) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.order = order
    }
}
