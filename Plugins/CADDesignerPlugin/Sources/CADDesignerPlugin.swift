import LumiKernel
import LumiUI

@MainActor
public final class CADDesignerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.cad-designer"
    public let name = "CADDesigner"
    public let order = 80

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
