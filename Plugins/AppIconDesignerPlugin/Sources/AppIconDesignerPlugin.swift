import LumiKernel
import LumiUI

@MainActor
public final class AppIconDesignerPlugin: LumiPlugin {
    public let id = "AppIconDesigner"
    public let name = "AppIconDesigner"
    public let order = 79

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
