import LumiKernel
import LumiUI

@MainActor
public final class ProjectIssueScannerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.project-issue-scanner"
    public let name = "Project Issue Scanner"
    public let order = 97
public static let policy: LumiPluginPolicy = .disabled

    public var policy: LumiPluginPolicy { .disabled }

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
