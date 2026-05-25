import Foundation
import AgentToolKit

/// Returns an overview of a project for the model: path, type, structure (2 levels), Git info, manifests, README preview, key files.
struct ProjectOverviewTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    let name = "project_overview"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取项目概览：路径、类型、两级目录结构、Git 信息（分支、远端、是否有变更）、清单文件、README 预览和关键文件。适合在深入处理项目前先了解整体情况。"
        case .english:
            return "Get a project overview: path, type, two-level directory structure, Git (branch, remote, clean/dirty), manifest files, README preview, key files. Use when you need to understand the project before diving in."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
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

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查看项目概览"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let path = arguments["path"]?.value as? String ?? FileManager.default.currentDirectoryPath
        let root = URL(fileURLWithPath: path).standardizedFileURL

        if Self.verbose {
            if ProjectOverviewPlugin.verbose {
                            ProjectOverviewPlugin.logger.info("\(self.t)Project overview: \(root.path)")
            }
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
