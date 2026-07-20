import EditorService
import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import os

/// Editor kernel plugin
///
/// Registers EditorCore with LumiKernel, bridging the editor subsystem
/// to the app's plugin and theme infrastructure.
@MainActor
public final class EditorKernelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor")
    nonisolated public static let emoji = "\u{1F4DD}"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.editor"
    public let name = "Editor Plugin"
    public let order = 50  // Core plugin

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // Register the EditorService with an extension registry.
        // EditorService from the EditorService module doesn't conform to
        // EditorServiceProviding, so we use a thin adapter.
        let extensionRegistry = EditorExtensionRegistry()
        let editorService = EditorService(editorExtensionRegistry: extensionRegistry)
        let adapter = EditorServiceProvidingAdapter(wrapping: editorService)
        kernel.registerEditor(adapter)
        if Self.verbose {
            Self.logger.info("\(Self.t)Registered Editor service")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Editor plugin booted")
        }
    }
}

/// Thin adapter that bridges EditorService (EditorService module) to EditorServiceProviding.
@MainActor
private final class EditorServiceProvidingAdapter: EditorServiceProviding {
    private let editorService: EditorService

    @Published var currentFilePath: String?
    @Published var currentThemeId: String = "xcode-dark"

    init(wrapping service: EditorService) {
        self.editorService = service
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
        editorService.theme.syncInitialThemeFromExternal(themeId)
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

    // MARK: - EditorServiceProviding default implementations (unused)
}
