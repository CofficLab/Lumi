import LumiKernel
import LumiUI

@MainActor
public final class OnboardingPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.onboarding"
    public let name = "Onboarding"
    public let order = 10

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
