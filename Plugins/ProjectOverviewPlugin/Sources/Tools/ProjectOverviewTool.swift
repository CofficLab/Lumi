import Foundation
import LumiKernel
import SuperLogKit

/// 项目概览工具。
///
/// 返回项目概览：路径、类型、两级目录结构、Git 信息（分支、远端、是否有变更）、清单文件、README 预览和关键文件。适合在深入处理项目前先了解整体情况。
public struct ProjectOverviewTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "project_overview",
        displayName: "Project Overview",
        description: "Get a project overview: path, type, two-level directory structure, Git (branch, remote, clean/dirty), manifest files, README preview, key files. Use when you need to understand the project before diving in."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Project root path. Omit to use current working directory."),
                ]),
            ]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查看项目概览"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let path = arguments.string("path") ?? FileManager.default.currentDirectoryPath
        let root = URL(fileURLWithPath: path).standardizedFileURL

        if Self.verbose {
            if ProjectOverviewPlugin.verbose {
                ProjectOverviewPlugin.logger.info("\(Self.t)Project overview: \(root.path)")
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
