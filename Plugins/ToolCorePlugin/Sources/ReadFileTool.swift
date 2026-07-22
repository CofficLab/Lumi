import AppKit
import SuperLogKit
import Foundation
import LumiKernel
import FileSystemKit
import os

/// 文件读取工具
///
/// 允许 AI 助手按行读取指定路径的 UTF-8 文本文件，默认每次最多 250 行。
public struct ReadFileTool: LumiAgentTool, SuperLog {
    public static let info = LumiAgentToolInfo(
        id: "read_file",
        displayName: LumiPluginLocalization.string("Read File", bundle: .module),
        description: LumiPluginLocalization.string(
            "Read UTF-8 text from a file by line range. Large files should be read in chunks with offset and limit.",
            bundle: .module
        )
    )
    public static let tags: Set<LumiToolTag> = [.fileSystem, .readOnly, .fast]

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.read-file")
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose = false

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The absolute path to the UTF-8 text file to read")
                ]),
                "offset": .object([
                    "type": .string("integer"),
                    "description": .string(
                        "1-based line number to start reading from. Negative values count backwards from the end (e.g. -1 is the last line)."
                    )
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string(
                        "Maximum number of lines to return. Defaults to 250 and is capped at 250 per request."
                    )
                ])
            ]),
            "required": .array([.string("path")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let path = arguments["path"]?.stringValue else { return "读取文件" }
        let fileName = URL(fileURLWithPath: path).lastPathComponent

        if let offset = intArgument(arguments["offset"]) {
            if let limit = intArgument(arguments["limit"]) {
                return "读取 \(fileName)（第 \(offset) 行起，最多 \(limit) 行）"
            }
            return "读取 \(fileName)（从第 \(offset) 行起）"
        }

        return "读取 \(fileName)"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw NSError(
                domain: "ReadFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"]
            )
        }

        if !context.isPathAllowed(path) {
            throw NSError(
                domain: "ReadFileTool",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(path)\n\n此路径不在允许的文件操作范围内。"]
            )
        }

        if Self.verbose {
            Self.logger.info("\(self.t)开始读取文件：\(path)")
        }

        do {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let data = try Data(contentsOf: url)

            // 图片文件：读取并以图片形式回传给 LLM（而非报 UTF-8 错误）。
            if let mimeType = Self.imageMimeType(forPathExtension: url.pathExtension),
               let imageMessage = Self.readAsImage(data: data, url: url, mimeType: mimeType, context: context) {
                if Self.verbose {
                    Self.logger.info("\(self.t)识别为图片文件：\(path)，mimeType=\(mimeType)，大小=\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                }
                return imageMessage
            }

            guard let content = String(data: data, encoding: .utf8) else {
                if Self.verbose {
                    Self.logger.warning("\(self.t)文件不是有效 UTF-8 文本：\(path)")
                }
                return "Error: File content is not valid UTF-8 text."
            }

            // 记录「已读取」快照：供 edit_file 做乐观并发控制——若文件在读取后被外部修改，
            // 编辑会被拒绝并提示重新读取，避免基于过期内容覆盖外部改动。
            let modificationDate = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            if let modificationDate {
                ReadFileStateRegistry.shared.recordRead(
                    conversationID: context.conversationID,
                    path: url.path,
                    snapshot: WorkspaceReadFileSnapshot(modificationDate: modificationDate)
                )
                if Self.verbose {
                    Self.logger.info("\(self.t)记录读取快照：\(url.path)，modificationDate=\(modificationDate)")
                }
            }

            let request = ReadFileLineReader.Request(
                offset: intArgument(arguments["offset"]),
                limit: intArgument(arguments["limit"])
            )
            let result = ReadFileLineReader.read(content: content, request: request)

            if Self.verbose {
                Self.logger.info("\(self.t)读取完成：\(path)，总行数=\(result.totalLines)，返回行数=\(result.formattedContent.split(separator: "\n").count)")
            }

            if result.totalLines == 0 {
                return ""
            }

            return result.formattedContent
        } catch {
            if Self.verbose {
                Self.logger.error("\(self.t)读取文件失败：\(path) - \(error.localizedDescription)")
            }
            return "Error reading file: \(error.localizedDescription)"
        }
    }

    // MARK: - Image Handling

    /// 已知图片扩展名到 MIME 类型的映射。返回 `nil` 表示不是图片。
    private static func imageMimeType(forPathExtension ext: String) -> String? {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        default: return nil
        }
    }

    /// 将文件数据作为图片读取并注册到执行上下文，供 LLM 作为视觉输入。
    /// - Returns: 成功时返回面向 LLM 的文本说明；无法识别为有效图片时返回 `nil`（交由上层按文本/报错处理）。
    private static func readAsImage(
        data: Data,
        url: URL,
        mimeType: String,
        context: LumiToolExecutionContext
    ) -> String? {
        // NSImage(data:) 与 representations 读取在后台线程安全可用。
        guard let image = NSImage(data: data), image.isValid else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)图片数据无效：\(url.lastPathComponent)")
            }
            return nil
        }

        let pixelSize = image.representations.reduce(into: (width: 0, height: 0)) { acc, rep in
            acc.width = max(acc.width, rep.pixelsWide)
            acc.height = max(acc.height, rep.pixelsHigh)
        }

        context.attachImage(
            LumiImageAttachment(
                mimeType: mimeType,
                base64Data: data.base64EncodedString(),
                fileName: url.lastPathComponent
            )
        )

        let sizeDescription = pixelSize.width > 0 && pixelSize.height > 0
            ? "，\(pixelSize.width)×\(pixelSize.height) 像素"
            : ""
        let byteCount = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        let result = "已加载图片：\(url.lastPathComponent)\(sizeDescription)（\(byteCount)）。图片已随结果返回，可直接查看其内容。"
        
        if Self.verbose {
            Self.logger.info("\(Self.t)图片读取成功：\(url.lastPathComponent)，\(sizeDescription)，\(byteCount)")
        }
        
        return result
    }

    private func intArgument(_ value: LumiJSONValue?) -> Int? {
        switch value {
        case .int(let intValue):
            intValue
        case .double(let doubleValue):
            Int(doubleValue)
        default:
            nil
        }
    }
}
