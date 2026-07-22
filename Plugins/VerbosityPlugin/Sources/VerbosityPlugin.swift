import LumiKernel
import LumiUI

@MainActor
public final class VerbosityPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.verbosity"
    public let name = "Verbosity"
    public let order = 85
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onReady(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - Chat Section Toolbar Bar

    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] {
        [
            ChatSectionToolbarBarItem(id: id) {
                VerbosityToolbarView(kernel: kernel)
            }
        ]
    }
}
