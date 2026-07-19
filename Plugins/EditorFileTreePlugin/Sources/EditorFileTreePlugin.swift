import LumiKernel
import LumiUI

@MainActor
public final class EditorFileTreePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-rail-file-tree"
    public let name = "Editor File Tree"
    public let order = 0

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
