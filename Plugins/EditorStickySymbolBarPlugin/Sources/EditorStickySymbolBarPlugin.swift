import EditorService
import LumiKernel
import LumiUI
import SwiftUI
import os

/// Editor Sticky Symbol Bar Plugin
@MainActor
public final class EditorStickySymbolBarHeaderPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-sticky-symbol-bar-header")

    public let id = "com.coffic.lumi.plugin.editor-sticky-symbol-bar-header"
    public let name = "Editor Sticky Symbol Bar"
    public let order = 85

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerPanelHeaderItem(
            PanelHeaderItem(id: id) {
                if let service = EditorStickySymbolBarBridge.editorServiceProvider?() {
                    EditorStickySymbolBarHeaderView(service: service)
                } else {
                    EmptyView()
                }
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}