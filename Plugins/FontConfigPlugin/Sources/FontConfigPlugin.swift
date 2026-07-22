import LumiKernel
import LumiUI

@MainActor
public final class FontConfigPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.font-config"
    public let name = "Font Config"
    public let order = 78
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
