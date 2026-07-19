import LumiKernel
import LumiUI

@MainActor
public final class EditorChatPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-chat"
    public let name = "Editor Chat"
    public let order = 6

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
