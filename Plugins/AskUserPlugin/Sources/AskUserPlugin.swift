import LumiKernel
import LumiUI

@MainActor
public final class AskUserPlugin: LumiPlugin {
    public let id = "plugin-ask-user"
    public let name = "用户询问插件"
    public let order = 100

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
