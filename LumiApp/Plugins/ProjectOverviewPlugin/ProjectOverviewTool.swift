import Foundation
import MagicKit

/// Returns an overview of a project for the model: path, type, structure (2 levels), Git info, manifests, README preview, key files.
struct ProjectOverviewTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false
    let name = "project_overview"
    let description = "Get a project overview: path, type, two-level directory structure, Git (branch, remote, clean/dirty), manifest files, README preview, key files. Use when you need to understand the project before diving in."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Project root path. Omit to use current working directory."
                ]
            ]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = arguments["path"]?.value as? String ?? FileManager.default.currentDirectoryPath
        let root = URL(fileURLWithPath: path).standardizedFileURL

        if Self.verbose {
            ProjectOverviewPlugin.logger.info("\(self.t)Project overview: \(root.path)")
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            return "Error: Path does not exist or is not a directory: \(path)"
        }

        let fm = FileManager.default
        do {
            _ = try fm.contentsOfDirectory(atPath: root.path)
        } catch {
            return "Error: Cannot read directory: \(error.localizedDescription)"
        }

        var sections: [String] = []

        sections.append("## Project Overview\n\n**Path**: \(root.path)")
        sections.append("### Project type\n\(ProjectTypeSection.render(at: root))")
        sections.append("### Structure (root + one level down)\n\(StructureSection.render(at: root))")
        sections.append("### Git\n\(GitSection.render(at: root))")
        sections.append("### Manifest & config\n\(ManifestSection.render(at: root))")

        let readmePreview = ReadmePreviewSection.render(at: root)
        if !readmePreview.isEmpty {
            sections.append("### README preview\n\(readmePreview)")
        }

        sections.append("### Key files\n\(KeyFilesSection.render(at: root))")

        return sections.joined(separator: "\n\n")
    }
}
