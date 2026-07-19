import LumiKernel
import LumiUI

@MainActor
public final class ShowImagePlugin: LumiPlugin {
    public let id = "ShowImage"
    public let name = "ShowImage"
    public let order = 97

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
