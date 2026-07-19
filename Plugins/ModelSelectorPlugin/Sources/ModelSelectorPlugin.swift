import LumiKernel
import LumiUI

@MainActor
public final class ModelSelectorPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.model-selector"
    public let name = "Model Selector"
    public let order = 82

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
