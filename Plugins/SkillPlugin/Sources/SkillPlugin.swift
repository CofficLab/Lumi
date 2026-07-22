import LumiKernel
import LumiUI

@MainActor
public final class SkillPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.skill"
    public let name = "Skills"
    public let order = 51
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
