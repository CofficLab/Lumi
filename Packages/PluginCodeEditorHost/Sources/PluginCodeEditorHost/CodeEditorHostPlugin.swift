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
@MainActor
public final class CodeEditorHostPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
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

    /// 历史实现把编辑器配置与键位写在 `Application Support/EditorService/`（目录名来自
    /// `EditorHostEnvironment.storageDirectoryName`），该路径不在 StorageProviding 的
    /// 版本化数据根内，升级时不会被搬迁。
    public let legacyDataDirectoryNames: [String] = []

    /// 把旧目录 `Application Support/<storageDirectoryName>/` 的内容复制到插件专属目录。
    ///
    /// 旧路径不由本插件独占（各宿主共用），且不在版本根内，因此无法走
    /// `copyLegacyDirectories` 的版本扫描，直接按 Application Support 定位。
    /// 复制而非移动，保留原文件以便回退；目标已存在的文件不覆盖，可安全重试。
    public func migrateData(context: PluginDataMigrationContext) throws {
        let fileManager = FileManager.default
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        let legacyDirectory = applicationSupport
            .appending(path: EditorHostEnvironment.current.storageDirectoryName, directoryHint: .isDirectory)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: legacyDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        let destination = context.currentPluginDataDirectory
        try PluginDataMigrationUtility.mergeDirectoryContents(
            from: legacyDirectory,
            to: destination,
            fileManager: fileManager
        )
        Self.logger.info("\(Self.t)Migrated editor settings from legacy \(legacyDirectory.lastPathComponent) directory")
    }

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
