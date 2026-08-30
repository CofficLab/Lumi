import EditorService
import EditorLanguageRuntime
import KernelCore
import TreeSitterBash
import TreeSitterJavaScript
import TreeSitterJSON
import TreeSitterMarkdown
import TreeSitterPython
import TreeSitterSwift
import TreeSitterTSX
import TreeSitterTypeScript
import TreeSitterYAML
import KitSuperLog
import os

@MainActor
public final class CodeEditorLanguagesSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.editor-languages", category: "EditorLanguages")
    public static let pluginID = "com.coffic.lumi.plugin.editor-languages"

    public let id = pluginID
    public let order = 2
    public let dependencies = ["com.coffic.lumi.plugin.editor-host"]
    public let metadata = PluginMetadata(
        id: pluginID,
        name: "Built-in Editor Languages",
        description: "Syntax highlighting for common project files.",
        version: "1.0.0",
        category: .editor,
        stage: .stable,
        policy: .required
    )

    private var registeredLanguageIDs: [String] = []
    private var registeredGrammarIDs: [String] = []
    private var providers: [BuiltInGrammarProvider] = []

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let editor = kernel.resolveProvider(EditorService.self) else {
            throw KernelCoreError.providerNotRegistered(type: EditorService.self)
        }

        let providers = Self.makeProviders()
        for descriptor in Self.descriptors {
            editor.editorExtensions.registerLanguage(descriptor)
        }
        for provider in providers {
            editor.editorExtensions.registerGrammarProvider(provider)
        }

        registeredLanguageIDs = Self.descriptors.map(\.languageId)
        registeredGrammarIDs = providers.map(\.grammarId)
        self.providers = providers
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        guard let editor = kernel.resolveProvider(EditorService.self) else { return }
        for languageID in registeredLanguageIDs {
            editor.editorExtensions.languageRegistry.unregister(languageId: languageID)
        }
        for grammarID in registeredGrammarIDs {
            editor.editorExtensions.languageRegistry.unregisterGrammarProvider(grammarId: grammarID)
        }
        registeredLanguageIDs.removeAll()
        registeredGrammarIDs.removeAll()
        providers.removeAll()
    }

    public static let descriptors: [EditorLanguageRuntime.EditorLanguageDescriptor] = [
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "swift",
            displayName: "Swift",
            fileExtensions: ["swift"],
            shebangAliases: ["swift"],
            lineComment: "//",
            rangeCommentOpen: "/*",
            rangeCommentClose: "*/",
            lspLanguageId: "swift"
        ),
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "javascript",
            displayName: "JavaScript",
            fileExtensions: ["js", "jsx", "mjs", "cjs"],
            shebangAliases: ["node"],
            lineComment: "//",
            rangeCommentOpen: "/*",
            rangeCommentClose: "*/",
            lspLanguageId: "javascript"
        ),
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "typescript",
            displayName: "TypeScript",
            fileExtensions: ["ts", "mts", "cts"],
            lineComment: "//",
            rangeCommentOpen: "/*",
            rangeCommentClose: "*/",
            lspLanguageId: "typescript"
        ),
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "typescriptreact",
            displayName: "TypeScript React",
            fileExtensions: ["tsx"],
            lineComment: "//",
            rangeCommentOpen: "/*",
            rangeCommentClose: "*/",
            highlightLanguageId: "tsx",
            lspLanguageId: "typescriptreact"
        ),
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "json",
            displayName: "JSON",
            fileExtensions: ["json", "jsonc"],
            lspLanguageId: "json"
        ),
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "markdown",
            displayName: "Markdown",
            fileExtensions: ["md", "markdown", "mdown", "mkd"],
            highlightLanguageId: "markdown",
            lspLanguageId: "markdown"
        ),
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "python",
            displayName: "Python",
            fileExtensions: ["py", "pyi", "pyw"],
            shebangAliases: ["python", "python3"],
            lineComment: "#",
            lspLanguageId: "python"
        ),
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "shellscript",
            displayName: "Shell Script",
            fileExtensions: ["sh", "bash", "zsh"],
            shebangAliases: ["sh", "bash", "zsh"],
            lineComment: "#",
            highlightLanguageId: "bash",
            lspLanguageId: "shellscript"
        ),
        EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "yaml",
            displayName: "YAML",
            fileExtensions: ["yaml", "yml"],
            lineComment: "#",
            lspLanguageId: "yaml"
        ),
    ]

    private static func makeProviders() -> [BuiltInGrammarProvider] {
        [
            BuiltInGrammarProvider(grammarId: "swift", languagePointer: { tree_sitter_swift() }),
            BuiltInGrammarProvider(grammarId: "javascript", languagePointer: { tree_sitter_javascript() }),
            BuiltInGrammarProvider(grammarId: "typescript", languagePointer: { tree_sitter_typescript() }),
            BuiltInGrammarProvider(grammarId: "tsx", languagePointer: { tree_sitter_tsx() }),
            BuiltInGrammarProvider(grammarId: "json", languagePointer: { tree_sitter_json() }),
            BuiltInGrammarProvider(grammarId: "markdown", languagePointer: { tree_sitter_markdown() }),
            BuiltInGrammarProvider(grammarId: "python", languagePointer: { tree_sitter_python() }),
            BuiltInGrammarProvider(grammarId: "bash", languagePointer: { tree_sitter_bash() }),
            BuiltInGrammarProvider(grammarId: "yaml", languagePointer: { tree_sitter_yaml() }),
        ]
    }
}
