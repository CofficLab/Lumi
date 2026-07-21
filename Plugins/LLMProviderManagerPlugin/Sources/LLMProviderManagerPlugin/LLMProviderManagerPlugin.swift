import Foundation
import LumiCoreLLMProvider
import LumiKernel
import SuperLogKit
import os

/// LLM Provider Manager Plugin
///
/// Registers an `LLMProviderProviding` implementation with the kernel.
/// Individual LLM Provider plugins call
/// `kernel.llmProvider?.registerLLMProvider(...)` in their own
/// `register(kernel:)` to make themselves available.
///
/// Order = 10 (after `PluginManagementPlugin` order 5, before any
/// LLM Provider plugin in the 100+ range), so that the manager is in
/// place when downstream LLM provider plugins attempt to register.
@MainActor
public final class LLMProviderManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager")
    public nonisolated static let emoji = "🧠"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.llm-provider-manager"
    public let name = "LLM Provider Manager"
    public let order = 10
    public static let policy: LumiPluginPolicy = .disabled // 核心插件

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)LLMProviderManagerPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let service = LLMProviderManager()
        kernel.registerLLMProviderService(service)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 LLMProviderManager 到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)LLMProviderManagerPlugin boot 完成")
        }
    }
}
