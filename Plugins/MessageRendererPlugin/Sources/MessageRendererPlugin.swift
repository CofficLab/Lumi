import LumiKernel
import LumiUI

@MainActor
public final class MessageRendererPlugin: LumiPlugin {
    public let id = "CoreMessageRenderer"
    public let name = "核心消息渲染器"
    public let order = 10

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
