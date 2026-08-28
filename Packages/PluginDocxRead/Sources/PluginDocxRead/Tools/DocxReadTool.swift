import KitAgentTool
import Foundation

/// DOCX 读取工具
///
/// 读取指定 DOCX 文件的正文内容，供 Agent 分析或总结。
/// 内部使用 macOS 自带 `/usr/bin/textutil` 将 DOCX 转为纯文本。
///
/// 由旧版 `LumiAgentTool` 迁移为 `SuperAgentTool`；移除 `kernel.isPathAllowed`
/// 沙盒检查（破坏性工具才需授权，本工具只读）。
public struct DocxReadTool: SuperAgentTool {
    public let name = "read_docx"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        LumiPluginLocalization.string(
            "Extract text from a DOCX file and return its content.",
            bundle: .module
        )
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the DOCX file to read",
                ],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments["path"]?.value as? String else { return "读取 DOCX" }
        return "读取 \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(
                domain: "DocxReadTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"]
            )
        }

        let sourceURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return "Error: File not found at path: \(sourceURL.path)"
        }

        let text = try Self.extractText(from: sourceURL)

        return text.isEmpty ? "(empty DOCX)" : text
    }

    // MARK: - DOCX Extraction

    private static func extractText(from sourceURL: URL) throws -> String {
        try extractTextUsingTextutil(from: sourceURL)
    }

    private static func extractTextUsingTextutil(from sourceURL: URL) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".txt")

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = [
            "-convert", "txt",
            "-output", tempFile.path,
            sourceURL.path
        ]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: tempFile.path) else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorDesc = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "com.coffic.lumi.plugin.docx-read.textutil",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "textutil conversion failed: \(errorDesc)"]
            )
        }

        return try String(contentsOf: tempFile, encoding: .utf8)
    }
}
