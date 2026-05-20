import Foundation

public struct MCPServerConfig: Identifiable, Codable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let command: String
    public let args: [String]
    public let env: [String: String]
    public var disabled: Bool
    public var homepage: String?
    public var url: String?
    public var transportType: MCPTransportType?

    public init(
        name: String,
        command: String,
        args: [String],
        env: [String: String],
        disabled: Bool = false,
        homepage: String? = nil,
        url: String? = nil,
        transportType: MCPTransportType? = nil
    ) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.disabled = disabled
        self.homepage = homepage
        self.url = url
        self.transportType = transportType
    }
}
