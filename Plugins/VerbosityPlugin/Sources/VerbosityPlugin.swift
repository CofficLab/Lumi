import LumiKernel
import LumiUI

@MainActor
public final class VerbosityPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.verbosity"
    public let name = "Verbosity"
    public let order = 85
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
