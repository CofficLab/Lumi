import LumiKernel
import LumiUI

@MainActor
public final class DocxReadPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.docx-read"
    public let name = "Docx Read"
    public let order = 90

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
