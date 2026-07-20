import LumiKernel
import LumiUI

@MainActor
public final class GitPlugin: LumiPlugin {
    public let id = "GitPlugin"
    public let name = "Git"
    public let order = 11
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
