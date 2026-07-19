import LumiKernel
import LumiUI

@MainActor
public final class SkillPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.skill"
    public let name = "Skills"
    public let order = 51

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
