import LLMKit
import LumiKernel
import LumiUI

@MainActor
public final class AliyunPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.aliyun"
    public let name = "阿里云 CodingPlan"
    public let order = 105

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}
}
