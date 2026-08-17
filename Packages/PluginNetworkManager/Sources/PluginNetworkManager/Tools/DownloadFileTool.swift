import AgentToolKit
import Foundation
import SuperLogKit

/// 下载文件工具
///
/// 使用 URLSession 下载文件到本地磁盘。
struct DownloadFileTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📥"
    nonisolated static let verbose = false

    let name = "network_download_file"

    func description(for language: LanguagePreference) -> String {
        "Download a file from URL using the system's NetworkManager service. Supports HTTP/HTTPS. Returns the local file path after successful download."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "文件下载链接 (HTTP/HTTPS)",
                ],
                "filename": [
                    "type": "string",
                    "description": "可选，保存的文件名。不提供则使用 URL 中的文件名",
                ],
                "directory": [
                    "type": "string",
                    "description": "可选，保存目录的绝对路径。不提供则使用临时目录",
                ],
            ],
            "required": ["url"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let urlString = NetworkToolSupport.string(arguments, "url"),
           let url = URL(string: urlString) {
            let name = url.lastPathComponent
            if !name.isEmpty && name != "/" {
                return "下载 \(name)"
            }
        }
        return "下载文件"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let urlString = NetworkToolSupport.string(arguments, "url"),
              let url = URL(string: urlString) else {
            return "❌ 错误：无效的 URL"
        }

        guard url.scheme == "http" || url.scheme == "https" else {
            return "❌ 错误：仅支持 HTTP/HTTPS 协议"
        }

        // 确定文件名
        let filename: String
        if let customName = NetworkToolSupport.string(arguments, "filename"), !customName.isEmpty {
            filename = customName
        } else {
            filename = extractFilename(from: url)
        }

        // 确定保存目录
        let directory: URL
        if let dirPath = NetworkToolSupport.string(arguments, "directory") {
            let dirURL = URL(fileURLWithPath: dirPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory) || !isDirectory.boolValue {
                return "❌ 错误：目录不存在或不是有效的目录: \(dirPath)"
            }
            directory = dirURL
        } else {
            directory = FileManager.default.temporaryDirectory
        }

        let destination = directory.appendingPathComponent(filename)

        // 使用 URLSession 下载
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                return "❌ 下载失败: HTTP \(statusCode)\nURL: \(url.absoluteString)"
            }

            try data.write(to: destination)
            let size = fileSizeString(at: destination)
            return """
            ✅ 下载完成
            文件名: \(filename)
            大小: \(size)
            路径: \(destination.path)
            """
        } catch {
            return "❌ 下载失败: \(error.localizedDescription)\nURL: \(url.absoluteString)"
        }
    }

    private func extractFilename(from url: URL) -> String {
        let pathComponent = url.lastPathComponent
        if !pathComponent.isEmpty, pathComponent != "/", !pathComponent.contains("?") {
            return pathComponent
        }

        if let query = url.query {
            let pairs = query.components(separatedBy: "&")
            for pair in pairs {
                let keyValue = pair.components(separatedBy: "=")
                if keyValue.count == 2 {
                    let key = keyValue[0]
                    let value = keyValue[1].removingPercentEncoding ?? keyValue[1]
                    if key.lowercased() == "filename" || key.lowercased() == "file" {
                        return value
                    }
                }
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "download_\(formatter.string(from: Date()))"
    }

    private func fileSizeString(at url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = attrs[.size] as? Int64 else { return "unknown" }
        if bytes > 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        } else if bytes > 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else if bytes > 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }
}
