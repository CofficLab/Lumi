import LumiKernel
import LumiUI

@MainActor
public final class AppIconDesignerPlugin: LumiPlugin {
    public let id = "AppIconDesigner"
    public let name = "AppIconDesigner"
    public let order = 79
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
