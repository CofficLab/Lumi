import EditorService
import LumiKernel
import LumiPreviewKit
import Foundation
import SwiftUI
import os

/// Runtime configuration for inline preview.
@MainActor
public final class EditorPreviewPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-preview")

    public let id = "EditorPreview"
    public let name = "Inline Preview"
    public let order = 84
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}
}