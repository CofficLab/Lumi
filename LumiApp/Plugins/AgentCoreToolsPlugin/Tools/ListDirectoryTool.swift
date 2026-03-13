import Foundation
import MagicKit
import OSLog
import SwiftUI

struct ListDirectoryTool: AgentTool, SuperLog {
    nonisolated static let verbose = true

    let name = "ls"
    let description = "List files and directories at a given path. Useful for exploring the project structure."

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the directory to list"
                ],
                "recursive": [
                    "type": "boolean",
                    "description": "Whether to list subdirectories recursively (default: false)"
                ]
            ],
            "required": ["path"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(domain: "ListDirectoryTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"])
        }

        let recursive = arguments["recursive"]?.value as? Bool ?? false

        if Self.verbose {
            os_log("\(Self.t)列出目录：\(path.components(separatedBy: "/").last ?? path)（递归：\(recursive ? "是" : "否")）")
        }

        let fileManager = FileManager.default
        var result = ""
        let rootURL = URL(fileURLWithPath: path)

        guard fileManager.fileExists(atPath: path) else {
            if Self.verbose {
                os_log(.error, "\(Self.t)路径不存在：\(path)")
            }
            return "Error: Path does not exist."
        }

        do {
            if recursive {
                var stack = [rootURL]
                var count = 0

                while !stack.isEmpty {
                    if count > 500 {
                        result += "... (Too many files, stopping list)\n"
                        if Self.verbose {
                            os_log("\(Self.t)文件数量过多，已停止列表（限制 500 个）")
                        }
                        break
                    }

                    let currentURL = stack.removeFirst()

                    // Skip hidden
                    if currentURL.lastPathComponent.hasPrefix(".") && currentURL != rootURL { continue }

                    // Add to result (if not root)
                    if currentURL != rootURL {
                        let relativePath = currentURL.path.replacingOccurrences(of: path, with: "")
                        let isDir = (try? currentURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                        // Clean up leading slash if present
                        let cleanPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
                        result += "\(cleanPath)\(isDir ? "/" : "")\n"
                        count += 1
                    }

                    // If directory, add children to stack
                    let isDir = (try? currentURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if isDir {
                        let contents = try fileManager.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                        stack.append(contentsOf: contents)
                    }
                }

                if Self.verbose {
                    os_log("\(Self.t)递归列表完成：\(count) 个项目")
                }
                return result.isEmpty ? "(Empty directory)" : result
            } else {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                var visibleCount = 0
                for item in contents {
                    if item.hasPrefix(".") { continue } // Skip hidden
                    let fullPath = (path as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)
                    result += "\(item)\(isDir.boolValue ? "/" : "")\n"
                    visibleCount += 1
                }
                if Self.verbose {
                    os_log("\(Self.t)目录列表完成：\(visibleCount) 个项目")
                }
                return result.isEmpty ? "(Empty directory)" : result
            }
        } catch {
            os_log(.error, "\(Self.t)列出目录失败：\(error.localizedDescription)")
            return "Error listing directory: \(error.localizedDescription)"
        }
    }
}

