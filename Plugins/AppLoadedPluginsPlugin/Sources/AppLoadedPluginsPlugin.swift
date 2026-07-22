import LumiKernel
import LumiUI

@MainActor
public final class AppLoadedPluginsPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.app-loaded-plugins"
    public let name = "AppLoadeds"
    public let order = 79
public static let policy: LumiPluginPolicy = .disabled

    public var policy: LumiPluginPolicy { .disabled }

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
