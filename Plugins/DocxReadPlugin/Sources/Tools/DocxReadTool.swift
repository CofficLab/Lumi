import Foundation
import LumiKernel
import SuperLogKit

/// DOCX 读取工具
///
/// 读取指定 DOCX 文件的正文内容，供 Agent 分析或总结。
/// 内部使用 macOS 自带 `/usr/bin/textutil` 将 DOCX 转为纯文本。
public struct DocxReadTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "read_docx",
        displayName: LumiPluginLocalization.string("Read DOCX", bundle: .module),
        description: LumiPluginLocalization.string(
            "Extract text from a DOCX file and return its content.",
            bundle: .module
        )
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The absolute path to the DOCX file to read")
                ])
            ]),
            "required": .array([.string("path")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let path = arguments["path"]?.stringValue else { return "读取 DOCX" }
        return "读取 \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw NSError(
                domain: "DocxReadTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"]
            )
        }

        if !context.isPathAllowed(path) {
            throw NSError(
                domain: "DocxReadTool",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(path)\n\n此路径不在允许的文件操作范围内。"]
            )
        }

        let sourceURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return "Error: File not found at path: \(sourceURL.path)"
        }

        let text = try Self.extractText(from: sourceURL)

        if Self.verbose {
            DocxReadPlugin.logger.info("\(Self.t)Read DOCX path=\(sourceURL.path) length=\(text.count)")
        }

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
