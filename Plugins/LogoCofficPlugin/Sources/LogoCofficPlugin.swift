import LumiKernel
import LumiUI

@MainActor
public final class LogoCofficPlugin: LumiPlugin {
    public let id = "com.lumi.plugin.logo-coffic"
    public let name = "Coffic Logo"
    public let order = 100

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Logo items are registered in logoItems method
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func logoItems(kernel: LumiKernel) -> [LogoItem] {
        [
            LogoItem(
                id: id,
                order: order,
                makeView: { scene in
                    CofficLogoView(scene: scene)
                }
            )
        ]
    }
}
