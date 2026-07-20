import LumiKernel
import LumiUI

@MainActor
public final class FileLogPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.file-log"
    public let name = "File Log"
    public let order = 1
public static let policy: LumiPluginPolicy = .disabled

    public var policy: LumiPluginPolicy { .disabled }

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
