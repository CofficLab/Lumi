import EditorService
import Foundation
import LumiKernel
import SuperLogKit
import os

/// EditorKernel 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct EditorKernelOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // Register the EditorService with an extension registry.
        // EditorService from the EditorService module doesn't conform to
        // EditorServiceProviding, so we use a thin adapter.
        let extensionRegistry = EditorExtensionRegistry()
        let editorService = EditorService(editorExtensionRegistry: extensionRegistry)
        let adapter = EditorServiceProvidingAdapter(wrapping: editorService)
        kernel.registerEditor(adapter)
        if Self.verbose {
            Self.logger.info("\(Self.t)Registered Editor service")
            Self.logger.info("\(Self.t)Editor plugin booted")
        }
    }
}

/// Thin adapter that bridges EditorService (EditorService module) to EditorServiceProviding.
@MainActor
private final class EditorServiceProvidingAdapter: EditorServiceProviding {
    private let service: EditorService

    @Published var currentFilePath: String?
    @Published var currentThemeId: String = "xcode-dark"

    init(wrapping service: EditorService) {
        self.service = service
    }

    func openFile(at path: String) async throws {
        currentFilePath = path
    }

    func closeFile(at path: String) async {
        if currentFilePath == path {
            currentFilePath = nil
        }
    }

    func setCurrentTheme(_ themeId: String) throws {
        service.theme.syncInitialThemeFromExternal(themeId)
        currentThemeId = themeId
    }

    var allEditorThemes: [EditorThemeInfo] {
        []
    }

    func registerEditorTheme(_ theme: EditorThemeInfo) {}
    func unregisterEditorTheme(themeId: String) {}

    func editorSyntaxPalette(for themeId: String) -> EditorSyntaxPalette? {
        nil
    }

    // MARK: - Raw EditorService Access

    var rawEditorService: AnyObject? {
        service
    }
}
