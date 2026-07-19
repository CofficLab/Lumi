import LumiKernel
import LumiUI

@MainActor
public final class AppLoadedPluginsPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.app-loaded-plugins"
    public let name = "AppLoadeds"
    public let order = 79

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
