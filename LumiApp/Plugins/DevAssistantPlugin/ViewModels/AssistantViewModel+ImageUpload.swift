import Foundation
import MagicKit
import OSLog
import AppKit

// MARK: - 图片上传与附件管理

extension AssistantViewModel {
    // MARK: - 图片上传

    func handleImageUpload(url: URL) {
        if Self.verbose {
            os_log("\(self.t)📷 开始处理图片上传：\(url.lastPathComponent)")
        }

        // 读取图片数据
        guard let data = try? Data(contentsOf: url),
              let _ = NSImage(data: data) else {
            os_log(.error, "\(self.t)❌ 无效的图片文件")
            errorMessage = "Invalid image file"
            return
        }

        if Self.verbose {
            os_log("\(self.t)✅ 图片读取成功，大小：\(data.count) bytes")
        }

        let mimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"

        // 添加到待发送附件列表
        pendingAttachments.append(.image(id: UUID(), data: data, mimeType: mimeType, url: url))

        if Self.verbose {
            os_log("\(self.t)✅ 图片已添加到待发送列表，当前共 \(self.pendingAttachments.count) 个附件")
        }
    }

    func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }
}
