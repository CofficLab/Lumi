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
    private let extractText: @Sendable (URL) throws -> String
    private let validateDocument: @Sendable (URL) throws -> Void

    public init() {
        extractText = { try Self.extractText(from: $0) }
        validateDocument = { try Self.validateDocxPackage(at: $0) }
    }

    init(
        extractText: @escaping @Sendable (URL) throws -> String,
        validateDocument: @escaping @Sendable (URL) throws -> Void = { _ in }
    ) {
        self.extractText = extractText
        self.validateDocument = validateDocument
    }

    public func description(for language: LanguagePreference) -> String {
        pluginLocalization.string("Extract text from a DOCX file and return its content.")
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
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "File not found at path: \(sourceURL.path)"
            )
        }

        // textutil 对零字节、纯文本改名、截断文件同样以 0 退出并产出空文本，
        // 必须先确认输入是完整的 OOXML ZIP 包，否则空结果无法与损坏文件区分。
        do {
            try validateDocument(sourceURL)
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: error.localizedDescription
            )
        }

        let text = try extractText(sourceURL)

        // 有效但无正文的 DOCX 经 textutil 转换后只剩空白，同样属于空文档。
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(empty DOCX)" : text
    }

    // MARK: - DOCX Validation

    private static func validateDocxPackage(at url: URL) throws {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count >= 22,
              // ZIP 本地文件头签名 "PK\x03\x04"
              data[0] == 0x50, data[1] == 0x4B, data[2] == 0x03, data[3] == 0x04,
              let entryNames = centralDirectoryEntryNames(in: data),
              entryNames.contains("[Content_Types].xml"),
              entryNames.contains("word/document.xml") else {
            throw DocxReadToolError.invalidDocument(url.path)
        }
    }

    private static func centralDirectoryEntryNames(in data: Data) -> [String]? {
        let count = data.count
        guard count >= 22 else { return nil }

        // End of Central Directory 可能带最长 65535 字节注释，从尾部向前找签名。
        var searchOffset = count - 22
        let searchLimit = max(0, count - 22 - 65535)
        var eocdOffset: Int?
        while searchOffset >= searchLimit {
            if uint32(data, at: searchOffset) == 0x0605_4B50 {
                eocdOffset = searchOffset
                break
            }
            searchOffset -= 1
        }
        guard let eocdOffset,
              let entryCount = uint16(data, at: eocdOffset + 10),
              let directoryOffset = uint32(data, at: eocdOffset + 16).map(Int.init) else {
            return nil
        }

        var names: [String] = []
        var offset = directoryOffset
        for _ in 0..<Int(entryCount) {
            guard uint32(data, at: offset) == 0x0201_4B50,
                  let nameLength = uint16(data, at: offset + 28).map(Int.init),
                  let extraLength = uint16(data, at: offset + 30).map(Int.init),
                  let commentLength = uint16(data, at: offset + 32).map(Int.init) else {
                return nil
            }
            let nameStart = offset + 46
            guard nameStart <= count, nameLength <= count - nameStart else {
                return nil
            }
            names.append(String(decoding: data[nameStart..<(nameStart + nameLength)], as: UTF8.self))
            offset = nameStart + nameLength + extraLength + commentLength
        }
        return names
    }

    private static func uint16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= data.count - 2 else { return nil }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func uint32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= data.count - 4 else { return nil }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
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
        // 确定性回收管道 fd，避免依赖 autorelease pool 造成 fd 泄漏。
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        process.standardError = pipe

        try process.run()
        let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: tempFile.path) else {
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

enum DocxReadToolError: LocalizedError, Equatable {
    case invalidDocument(String)

    var errorDescription: String? {
        switch self {
        case .invalidDocument(let path):
            return "File is not a valid DOCX document: \(path)"
        }
    }
}
