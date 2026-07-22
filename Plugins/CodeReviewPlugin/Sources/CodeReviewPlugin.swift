import LumiKernel
import LumiUI

@MainActor
public final class CodeReviewPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.code-review"
    public let name = "Code Review"
    public let order = 17
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
