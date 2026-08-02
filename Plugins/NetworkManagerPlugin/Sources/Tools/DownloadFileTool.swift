import Foundation
import LumiKernel
import SuperLogKit

/// 下载文件工具
///
/// 使用 NetworkManager 的 NetworkProviding 服务下载文件。
public struct DownloadFileTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📥"
    public nonisolated static let verbose = false

    public static let info = LumiAgentToolInfo(
        id: "network_download_file",
        displayName: LumiPluginLocalization.string("Download File", bundle: .module),
        description: LumiPluginLocalization.string(
            "Download a file from URL using the system's NetworkManager service. Supports HTTP/HTTPS. Returns the local file path after successful download.",
            bundle: .module
        )
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "url": .object([
                    "type": .string("string"),
                    "description": .string("文件下载链接 (HTTP/HTTPS)")
                ]),
                "filename": .object([
                    "type": .string("string"),
                    "description": .string("可选，保存的文件名。不提供则使用 URL 中的文件名")
                ]),
                "directory": .object([
                    "type": .string("string"),
                    "description": .string("可选，保存目录的绝对路径。不提供则使用临时目录")
                ])
            ]),
            "required": .array([.string("url")])
        ])
    }

    public nonisolated func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        if let urlString = arguments["url"]?.stringValue,
           let url = URL(string: urlString) {
            let name = url.lastPathComponent
            if !name.isEmpty && name != "/" {
                return "下载 \(name)"
            }
        }
        return "下载文件"
    }

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .medium
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let urlString = arguments["url"]?.stringValue,
              let url = URL(string: urlString) else {
            return "❌ 错误：无效的 URL"
        }

        // 验证 URL 协议
        guard url.scheme == "http" || url.scheme == "https" else {
            return "❌ 错误：仅支持 HTTP/HTTPS 协议"
        }

        // 确定文件名
        let filename: String
        if let customName = arguments["filename"]?.stringValue, !customName.isEmpty {
            filename = customName
        } else {
            filename = extractFilename(from: url)
        }

        // 确定保存目录
        let directory: URL
        if let dirPath = arguments["directory"]?.stringValue {
            let dirURL = URL(fileURLWithPath: dirPath, isDirectory: true)
            // 验证目录存在
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory) || !isDirectory.boolValue {
                return "❌ 错误：目录不存在或不是有效的目录: \(dirPath)"
            }
            directory = dirURL
        } else {
            // 使用临时目录
            directory = FileManager.default.temporaryDirectory
        }

        let destination = directory.appendingPathComponent(filename)

        // 获取 NetworkProviding 服务
        guard let network = kernel.resolveService(NetworkProviding.self) else {
            return "❌ 错误：NetworkManager 服务不可用"
        }

        // 执行下载
        do {
            let localURL = try await network.download(
                from: url,
                to: destination,
                headers: [:],
                timeout: 300
            )

            let size = try fileSizeString(at: localURL)
            return """
            ✅ 下载完成
            文件名: \(filename)
            大小: \(size)
            路径: \(localURL.path)
            """
        } catch {
            return "❌ 下载失败: \(error.localizedDescription)\nURL: \(url.absoluteString)"
        }
    }

    @MainActor
    private func extractFilename(from url: URL) -> String {
        let pathComponent = url.lastPathComponent
        if !pathComponent.isEmpty, pathComponent != "/", !pathComponent.contains("?") {
            return pathComponent
        }

        // 尝试从查询参数提取
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

        // 使用时间戳作为默认文件名
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "download_\(formatter.string(from: Date()))"
    }

    @MainActor
    private func fileSizeString(at url: URL) throws -> String {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = attrs[.size] as? Int64 ?? 0
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
