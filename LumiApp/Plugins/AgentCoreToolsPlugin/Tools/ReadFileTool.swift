import Foundation
import MagicKit
import SwiftUI

/// 文件读取工具
///
/// 允许 AI 助手读取指定路径的文件内容。
struct ReadFileTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose: Bool = false
    private static let supportedImageExtensions: [String: String] = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "webp": "image/webp",
    ]

    let name = "read_file"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "读取指定路径的文件内容。可用于查看代码、配置文件或图片文件。对于 PNG、JPEG、GIF 和 WebP 图片，会将图片作为视觉输入返回给兼容的多模态模型。"
        case .english:
            return "Read the contents of a file at the given path. Use this to examine code, configuration files, or image files. For PNG, JPEG, GIF, and WebP images, the image is returned as visual input to compatible multimodal models."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the file to read"
                ]
            ],
            "required": ["path"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(
                domain: "ReadFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"]
            )
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)读取文件：\(path.components(separatedBy: "/").last ?? path)")
        }

        let fileURL = Self.fileURL(from: path)
        let expandedPath = fileURL.path

        do {
            let ext = fileURL.pathExtension.lowercased()
            if let mimeType = Self.supportedImageExtensions[ext] {
                let data = try Data(contentsOf: fileURL)
                guard !data.isEmpty else {
                    return "Error: Image file is empty: \(expandedPath)"
                }

                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)图片读取成功：\(expandedPath)")
                }

                return ToolImageResultCodec.encode(
                    content: "Image file read: \(expandedPath) (\(data.count) bytes, \(mimeType)). The image is attached as visual input.",
                    images: [ImageAttachment(data: data, mimeType: mimeType)]
                )
            }

            let data = try Data(contentsOf: fileURL)
            guard let content = String(data: data, encoding: .utf8) else {
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.error("\(self.t)文件内容不是有效的 UTF-8 文本")
                }
                return "Error: File content is not valid UTF-8 text. If this is an image, supported formats are: \(Self.supportedImageExtensions.keys.sorted().joined(separator: ", "))."
            }

            if content.count > 50_000 {
                let prefix = content.prefix(50_000)
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)文件过大，已截断输出（限制 50KB）")
                }
                return "\(prefix)\n... (File truncated due to size limit)"
            }

            if Self.verbose {
                AgentCoreToolsPlugin.logger.info("\(self.t)文件读取成功：\(content.count) 字符")
            }
            return content
        } catch {
            AgentCoreToolsPlugin.logger.error("\(self.t)读取文件失败：\(error.localizedDescription)")
            return "Error reading file: \(error.localizedDescription)"
        }
    }

    private static func fileURL(from path: String) -> URL {
        if let url = URL(string: path), url.isFileURL {
            return url
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath)
    }
}
