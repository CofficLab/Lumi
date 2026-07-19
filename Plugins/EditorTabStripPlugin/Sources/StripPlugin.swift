import EditorService
import LumiKernel
import LumiUI
import SwiftUI
import os

/// Editor Tab Strip Plugin
@MainActor
public final class StripHeaderPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-tab-strip")

    public let id = "com.coffic.lumi.plugin.editor-tab-strip-header"
    public let name = "Editor Tab Strip"
    public let order = 70

    public init() {}

    public func register(kernel: LumiKernel) throws {
        let editorService = kernel.editor?.editorService

        kernel.registerPanelHeaderItem(
            PanelHeaderItem(id: id) {
                if let service = editorService {
                    HeaderView(service: service, kernel: kernel)
                } else {
                    StripHeaderErrorView(pluginName: name)
                }
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}