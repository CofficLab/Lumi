import Foundation
import LumiKernel
import SuperLogKit
import os

/// EditorProvider Plugin OnBoot Hook
///
/// Registers EditorProviding service to the kernel during boot phase.
@MainActor
public struct EditorProviderOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-provider")
    nonisolated static let verbose = false

    public init() {}

    /// 注册调用方已创建的 provider 到内核。
    /// provider 的创建由 plugin 负责,以便其在 OnReady 阶段注入 EditorService。
    public func execute(_ provider: EditorProvider, kernel: LumiKernel) async throws {
        kernel.registerEditor(provider)

        if Self.verbose {
            Self.logger.info("\(Self.t)EditorProviderPlugin: registered EditorProviding to kernel")
        }
    }
}
