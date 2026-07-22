import LumiKernel
import LumiUI

@MainActor
public final class BrowserPlugin: LumiPlugin {
    public let id = "Browser"
    public let name = "Browser"
    public let order = 102
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
