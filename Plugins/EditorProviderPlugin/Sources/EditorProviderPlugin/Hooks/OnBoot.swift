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
    nonisolated static let verbose = true

    public init() {}

    public func execute(_ kernel: LumiKernel) async throws {
        let editorProvider = EditorProvider()
        kernel.registerEditor(editorProvider)

        if Self.verbose {
            Self.logger.info("EditorProviderPlugin: registered EditorProviding to kernel")
        }
    }
}
