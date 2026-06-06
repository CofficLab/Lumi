import Foundation
import SuperLogKit
import AgentToolKit
import SwiftUI
import WorkspaceFileKit

/// 文件读取工具
///
/// 允许 AI 助手读取指定路径的文件内容。
public struct ReadFileTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = false
    private static let supportedImageExtensions: [String: String] = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "webp": "image/webp",
    ]
    private let reader = WorkspaceFileReader(supportedImageExtensions: supportedImageExtensions)

    public let name = "read_file"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "读取指定路径的文件内容。可用于查看代码、配置文件或图片文件。对于 PNG、JPEG、GIF 和 WebP 图片，会将图片作为视觉输入返回给兼容的多模态模型。"
        case .english:
            return "Read the contents of a file at the given path. Use this to examine code, configuration files, or image files. For PNG, JPEG, GIF, and WebP images, the image is returned as visual input to compatible multimodal models."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let displayDesc: String
        switch language {
        case .chinese:
            displayDesc = "向用户展示当前操作描述，如：正在读取 xxx.swift"
        case .english:
            displayDesc = "A short description shown to the user, e.g. \"Reading xxx.swift\""
        }
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the file to read"
                ],
                "display_name": [
                    "type": "string",
                    "description": displayDesc
                ]
            ],
            "required": ["path"]
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument], context: ToolExecutionContext?) -> CommandRiskLevel {
        let baseRisk: CommandRiskLevel = .low
        guard let context else { return baseRisk }
        return AgentCoreToolRisk.elevatedRiskIfPathOutOfBounds(arguments: arguments, baseRisk: baseRisk, context: context)
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments["path"]?.value as? String else { return "读取文件" }
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        return "读取 \(fileName)"
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(
                domain: "ReadFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"]
            )
        }

        // 验证路径是否在允许的范围内
        if !context.isPathAllowed(path) {
            throw NSError(
                domain: "ReadFileTool",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(path)\n\n此路径不在允许的文件操作范围内。"]
            )
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)读取文件：\(path.components(separatedBy: "/").last ?? path)")
        }

        do {
            switch try reader.read(path: path) {
            case .image(let data, let mimeType, let resolvedPath):
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)图片读取成功：\(resolvedPath)")
                }

                return ToolImageResultCodec.encode(
                    content: "Image file read: \(resolvedPath) (\(data.count) bytes, \(mimeType)). The image is attached as visual input.",
                    images: [ImageAttachment(data: data, mimeType: mimeType)]
                )

            case .nonUTF8(_, let supportedImageExtensions):
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.error("\(self.t)文件内容不是有效的 UTF-8 文本")
                }
                return "Error: File content is not valid UTF-8 text. If this is an image, supported formats are: \(supportedImageExtensions.joined(separator: ", "))."

            case .text(let content, _, let truncated):
                if truncated {
                    if Self.verbose {
                        AgentCoreToolsPlugin.logger.info("\(self.t)文件过大，已截断输出（限制 50KB）")
                    }
                    return "\(content)\n... (File truncated due to size limit)"
                }

                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)文件读取成功：\(content.count) 字符")
                }
                return content
            }
        } catch let error as WorkspaceFileError {
            AgentCoreToolsPlugin.logger.error("\(self.t)读取文件失败：\(error.localizedDescription)")
            return "Error: \(error.localizedDescription)"
        } catch {
            AgentCoreToolsPlugin.logger.error("\(self.t)读取文件失败：\(error.localizedDescription)")
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}
