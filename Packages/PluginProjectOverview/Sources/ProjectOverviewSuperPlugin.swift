import KitAgentTool
import Foundation
import KernelCore
import ProviderProject
import ProviderToolManager
import ProviderPromptSuggestion

@MainActor
public final class ProjectOverviewSuperPlugin: SuperPlugin {
    public let id = "ProjectOverview"
    public let order = 14
    public let metadata = PluginMetadata(id: "ProjectOverview", name: "Project Overview", description: "Inspect a project's structure, metadata, and Git status.", category: .project, stage: .preview, policy: .alwaysOn)
    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(id: "\(id).overview", title: LumiPluginLocalization.string("Prompt.Suggestion.Overview", bundle: .module), order: order * 1_000, systemImage: "doc.text.magnifyingglass", visibility: .onlyWithProject)
    }
    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolManagerProviding).self)?.add(ProjectOverviewV2Tool(project: kernel.resolveProvider((any ProjectProviding).self)), pluginID: id)
    }
    public func onReady(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.register(promptSuggestion)
    }
    public func onEnable(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.register(promptSuggestion)
    }
    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
        kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: ProjectOverviewV2Tool.toolName)
    }
    public func onDisable(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
    }
}

public struct ProjectOverviewV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "project_overview"
    public let name = toolName
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "Get a project overview: path, type, structure, Git state, manifests, README preview, and key files." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["path": ["type": "string", "description": "Project root path. Omit to use the current project or working directory."]], "additionalProperties": false] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "查看项目概览" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = (arguments["path"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootPath = (path?.isEmpty == false ? path : await MainActor.run { project?.currentProject?.path }) ?? FileManager.default.currentDirectoryPath
        let root = URL(fileURLWithPath: rootPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else { return "Error: Path does not exist or is not a directory: \(rootPath)" }
        guard (try? FileManager.default.contentsOfDirectory(atPath: root.path)) != nil else { return "Error: Cannot read directory." }
        var sections = ["## Project Overview\n\n**Path**: \(root.path)", "### Project type\n\(ProjectTypeSection.render(at: root))", "### Structure (root + one level down)\n\(StructureSection.render(at: root))", "### Git\n\(GitSection.render(at: root))", "### Manifest & config\n\(ManifestSection.render(at: root))"]
        let readme = ReadmePreviewSection.render(at: root); if !readme.isEmpty { sections.append("### README preview\n\(readme)") }
        sections.append("### Key files\n\(KeyFilesSection.render(at: root))")
        return sections.joined(separator: "\n\n")
    }
}
