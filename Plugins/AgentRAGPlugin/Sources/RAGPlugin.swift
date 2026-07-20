import LumiKernel
import LumiUI

@MainActor
public final class RAGPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.rag"
    public let name = "RAG"
    public let order = 200
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // RAG capabilities are provided through RAGPluginService singleton.
    }

    public func boot(kernel: LumiKernel) async throws {
        RAGPluginRuntime.kernel = kernel
        RAGPluginService.configure(kernel: kernel)
        RAGPluginBootstrap.bootstrapRuntime(context: kernel)
    }
}
