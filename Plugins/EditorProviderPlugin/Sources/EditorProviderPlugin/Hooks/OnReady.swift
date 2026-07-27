import Foundation
import LumiKernel
import SuperLogKit
import os

/// EditorProvider Plugin OnReady Hook
///
/// Performs any post-boot initialization. Editor service registration
/// is already completed in OnBoot phase.
@MainActor
public struct EditorProviderOnReadyHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-provider")
    nonisolated static let verbose = false

    public init() {}

    public func execute(_ kernel: LumiKernel) throws {
        if Self.verbose {
            Self.logger.info("EditorProviderPlugin: onReady (service already registered in OnBoot)")
        }
    }
}
