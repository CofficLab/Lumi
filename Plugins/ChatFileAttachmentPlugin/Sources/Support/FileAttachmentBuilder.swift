import Foundation
import LumiKernel
import os
import SuperLogKit
import UniformTypeIdentifiers

/// 把用户选择的 `[URL]` 转换成附件集合的纯函数构建器。
///
/// 图片文件(png/jpg/gif/webp/bmp/tiff/heic)→ `LumiImageAttachment`,复用现有图片多模态管线;
/// 非图片文件 → `LumiFileAttachment`,文本类文件解码正文,二进制仅元数据。
///
/// 所有文件读取都经过 `startAccessingSecurityScopedResource` 安全沙盒访问
/// (`.fileImporter` 返回的 URL 是安全作用域的)。
enum FileAttachmentBuilder: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-file-attachment.builder")
    nonisolated static let verbose = true

    /// 构建结果:图片附件走图片链路,文件附件走文件链路。
    struct Outcome {
        let images: [LumiImageAttachment]
        let files: [LumiFileAttachment]
    }

    static func build(from urls: [URL]) -> Outcome {
        var images: [LumiImageAttachment] = []
        var files: [LumiFileAttachment] = []
        if Self.verbose {
            Self.logger.info("\(Self.t)build attachments start urls=\(urls.count)")
        }

        for url in urls {
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            process(url: url, images: &images, files: &files)
        }
        if Self.verbose {
            let imageBase64Chars = images.reduce(0) { $0 + $1.base64Data.count }
            let fileBase64Chars = files.reduce(0) { $0 + $1.base64Data.count }
            let fileTextChars = files.reduce(0) { $0 + ($1.textContent?.count ?? 0) }
            Self.logger.info("\(Self.t)build attachments done images=\(images.count) imageBase64Chars=\(imageBase64Chars) files=\(files.count) fileBase64Chars=\(fileBase64Chars) fileTextChars=\(fileTextChars)")
        }
        return Outcome(images: images, files: files)
    }

    private static func process(
        url: URL,
        images: inout [LumiImageAttachment],
        files: inout [LumiFileAttachment]
    ) {
        guard let data = try? Data(contentsOf: url) else { return }
        let fileName = url.lastPathComponent
        let mimeType = mimeType(for: url)
        if Self.verbose {
            Self.logger.info("\(Self.t)process attachment file=\(fileName) bytes=\(data.count) mimeType=\(mimeType)")
        }

        if isImage(mimeType: mimeType, url: url) {
            let base64 = data.base64EncodedString()
            if Self.verbose {
                Self.logger.info("\(Self.t)image attachment encoded file=\(fileName) bytes=\(data.count) base64Chars=\(base64.count)")
            }
            images.append(
                LumiImageAttachment(
                    mimeType: mimeType,
                    base64Data: base64,
                    fileName: fileName
                )
            )
        } else {
            let base64 = data.base64EncodedString()
            // 文本类文件:尝试 UTF-8 解码正文(用于发送时注入用户消息)
            let text: String?
            if let decoded = String(data: data, encoding: .utf8) {
                text = Self.cap(decoded)
            } else {
                text = nil
            }
            if Self.verbose {
                Self.logger.info("\(Self.t)file attachment encoded file=\(fileName) bytes=\(data.count) base64Chars=\(base64.count) textChars=\(text?.count ?? 0) isText=\(text != nil)")
            }
            files.append(
                LumiFileAttachment(
                    fileName: fileName,
                    mimeType: mimeType,
                    base64Data: base64,
                    textContent: text
                )
            )
        }
    }

    /// 文本正文截断阈值,避免超大文件撑爆消息。
    private static let maxTextChars = 100_000

    private static func cap(_ text: String) -> String {
        guard text.count > maxTextChars else { return text }
        let truncated = text.prefix(maxTextChars)
        return truncated + "\n…[truncated: file too large, \(text.count - maxTextChars) more chars omitted]"
    }

    // MARK: - 类型判定

    private static let imageMimePrefix = "image/"

    private static func isImage(mimeType: String, url: URL) -> Bool {
        if mimeType.hasPrefix(imageMimePrefix) { return true }
        // 兜底:用 UTType 判定
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.conforms(to: .image)
        }
        return false
    }

    /// 根据 URL 推断 MIME 类型;无法识别时回退到 `application/octet-stream`。
    private static func mimeType(for url: URL) -> String {
        let ext = url.pathExtension
        if !ext.isEmpty,
           let type = UTType(filenameExtension: ext),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}
