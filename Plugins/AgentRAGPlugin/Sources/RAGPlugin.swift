import LumiKernel
import LumiUI

@MainActor
public final class RAGPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.rag"
    public let name = "RAG"
    public let order = 200

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
