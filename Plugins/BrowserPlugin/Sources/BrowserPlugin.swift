import LumiKernel
import LumiUI

@MainActor
public final class BrowserPlugin: LumiPlugin {
    public let id = "Browser"
    public let name = "Browser"
    public let order = 102

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
