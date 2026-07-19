import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ConversationLanguagePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-language"
    public let name = "Language Selector"
    public let order = 83

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Services are registered via convenience methods
    }

    public func boot(kernel: LumiKernel) async throws {}
}
