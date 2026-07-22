import LumiKernel
import LumiUI

@MainActor
public final class EditorFileTreeV2Plugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-file-tree-v2"
    public let name = "Editor File Tree V2"
    public let order = 0
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
