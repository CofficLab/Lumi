import Foundation
import LumiKernel
import SuperLogKit
import os
import SuperLogKit

/// LLMProviderManager 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的所有初始化逻辑
@MainActor
public struct LLMProviderManagerOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let service = LLMProviderManager()
        // Self-register the bundled mock provider so the kernel always
        // has at least one usable LLM provider out of the box. Real
        // providers (Anthropic, OpenAI, …) will be registered by their
        // own plugins via `kernel.llmProvider?.registerLLMProvider(...)`.
        service.registerLLMProvider(MockLLMProvider())
        kernel.registerLLMProviderService(service)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 LLMProviderManager 到内核, 并自注册 MockLLMProvider")
            Self.logger.info("\(Self.t)LLMProviderManagerPlugin boot 完成")
        }
    }
}
