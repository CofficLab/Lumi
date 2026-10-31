import AppKit
import ProviderEditor
import ProviderStorage
import EditorLanguageRuntime
import EditorService
import EditorSource
import KernelCore
import LumiUI
import SwiftUI
import LumiLoggingKit
import os

/// KernelCore 的编辑器宿主：提供与旧宿主相同的 SourceEditor 语法高亮能力。
///
/// 不实现 `PluginDataMigrating`：旧数据目录 `Application Support/<storageDirectoryName>/`
/// 不作搬迁，配置与键位从新目录重新生成。
@MainActor
public final class CodeEditorHostPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.editor-host", category: "EditorHost")
    public let id = "com.coffic.lumi.plugin.editor-host"
    public let order = 1
    public let dependencies: [String] = []
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.editor-host",
        name: CodeEditorHostLocalization.string("Editor Host"),
        description: CodeEditorHostLocalization.string("Provides shared source editing and syntax highlighting."),
        version: "2.0.0",
        category: .editor,
        stage: .preview,
        policy: .alwaysOn
    )

    public init() {}

    private var editorService: EditorService?
    private var editorAdapter: EditorProvidingV2Adapter?
    private var embeddedEditorProvider: EmbeddedEditorSurfaceProvider?

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 存储路径注入必须早于任何 EditorService / Store 的首次访问：
        // `EditorConfigStore.store` 是 static let，首次访问即固化路径。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            EditorSettingsLifecycle.hostPersistenceRootURL = {
                storage.pluginDataDirectory(for: self.id)
            }
        }

        let registry = EditorExtensionRegistry()
        let service = EditorService(editorExtensionRegistry: registry)
        let contributions = EditorContributionRegistry(registry: registry)
        let adapter = EditorProvidingV2Adapter(service: service, extensions: contributions)
        adapter.surfaceBox.makeView = { [weak service] in
            guard let service else {
                return AnyView(EditorHostUnavailableView())
            }
            return AnyView(EditorSurfaceView(state: service.state))
        }
        let embeddedProvider = EmbeddedEditorSurfaceProvider(service: service)

        try kernel.registerProvider(EditorService.self, service)
        try kernel.registerProvider(EditorProviding.self, adapter)
        try kernel.registerProvider(EditorSurfaceProviding.self, adapter.surface)
        try kernel.registerProvider(EditorEmbeddedEditorProviding.self, embeddedProvider)

        editorService = service
        editorAdapter = adapter
        embeddedEditorProvider = embeddedProvider
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        editorService?.cleanupForTeardown()
        kernel.unregisterProvider(EditorEmbeddedEditorProviding.self)
        kernel.unregisterProvider(EditorSurfaceProviding.self)
        kernel.unregisterProvider(EditorProviding.self)
        kernel.unregisterProvider(EditorService.self)
        embeddedEditorProvider = nil
        editorAdapter = nil
        editorService = nil
    }
}

private struct EditorHostUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            CodeEditorHostLocalization.string("Editor unavailable"),
            systemImage: "exclamationmark.triangle",
            description: Text(CodeEditorHostLocalization.string("The editor service is no longer available."))
        )
    }
}

@MainActor
private final class EmbeddedEditorSurfaceProvider: EditorEmbeddedEditorProviding {
    private let service: EditorService

    init(service: EditorService) { self.service = service }

    func makeEmbeddedEditorView(text: Binding<String>, options: EditorEmbeddedEditorOptions) -> AnyView {
        AnyView(EmbeddedEditorHostView(
            text: text,
            options: options,
            language: service.editorExtensions.languageRegistry.context(for: options.languageID) ?? .plainText
        ))
    }
}

private struct EmbeddedEditorHostView: View {
    @Binding var text: String
    let options: EditorEmbeddedEditorOptions
    let language: EditorLanguageContext
    @State private var editorState = SourceEditorState()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SourceEditor($text, language: language, configuration: configuration, state: $editorState)
    }

    private var configuration: SourceEditorConfiguration {
        let resolved = LumiUIThemeRegistry.shared.resolvedEditorSyntax(colorScheme: colorScheme)
        let palette = resolved?.palette ?? .standard(isDark: colorScheme == .dark)
        return SourceEditorConfiguration(
            appearance: .init(
                theme: EditorSyntaxPaletteAdapter.makeEditorTheme(from: palette),
                themeIdentifier: resolved?.themeId ?? "embedded-\(options.languageID)-\(colorScheme == .dark ? "dark" : "light")",
                useThemeBackground: options.useThemeBackground,
                font: .monospacedSystemFont(ofSize: options.fontSize > 0 ? options.fontSize : NSFont.systemFontSize, weight: .regular),
                wrapLines: options.wrapLines,
                tabWidth: 4
            ),
            behavior: .init(isEditable: options.isEditable, isSelectable: options.isSelectable),
            layout: .init(additionalTextInsets: NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)),
            peripherals: .init(showGutter: options.showGutter, showMinimap: false, showReformattingGuide: false, showFoldingRibbon: false)
        )
    }
}
