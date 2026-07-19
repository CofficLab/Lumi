import LumiKernel
import LumiUI

@MainActor
public final class EditorSwiftPlugin: LumiPlugin {
    public let id = "EditorSwiftIntegration"
    public let name = "Swift Integration"
    public let order = 5

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
