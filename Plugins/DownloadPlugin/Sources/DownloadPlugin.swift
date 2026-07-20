import LumiKernel
import LumiUI

@MainActor
public final class DownloadPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.download-agent"
    public let name = "Download Agent"
    public let order = 92
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
