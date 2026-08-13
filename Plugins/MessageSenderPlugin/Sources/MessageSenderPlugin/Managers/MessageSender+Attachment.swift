import Foundation
import KernelLumi
import os

// MARK: - Attachment 挂起池

public extension MessageSender {
    /// 添加附件。幂等:同 `id` 已存在则忽略。
    func addAttachment(_ attachment: LumiImageAttachment) {
        guard !pendingAttachments.contains(where: { $0.id == attachment.id }) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)addAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))… 已存在,忽略")
            }
            return
        }
        pendingAttachments.append(attachment)
        if Self.verbose {
            Self.logger.info("\(Self.t)addAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))…, mime=\(attachment.mimeType), pool.size=\(self.pendingAttachments.count)")
        }
    }

    /// 按 id 移除挂起附件。id 不存在则 no-op。
    func removeAttachment(id: UUID) {
        let before = pendingAttachments.count
        pendingAttachments.removeAll { $0.id == id }
        if Self.verbose {
            Self.logger.info("\(Self.t)removeAttachment ➡️ id=\(id.uuidString.prefix(8))…, before=\(before), after=\(self.pendingAttachments.count)")
        }
    }

    /// 清空所有挂起附件。
    func clearAttachments() {
        let count = pendingAttachments.count
        pendingAttachments.removeAll()
        if Self.verbose {
            Self.logger.info("\(Self.t)clearAttachments ➡️ cleared \(count) items")
        }
    }

    /// 添加文件附件。幂等:同 `id` 已存在则忽略。
    func addFileAttachment(_ attachment: LumiFileAttachment) {
        guard !pendingFileAttachments.contains(where: { $0.id == attachment.id }) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)addFileAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))… 已存在,忽略")
            }
            return
        }
        pendingFileAttachments.append(attachment)
        if Self.verbose {
            Self.logger.info("\(Self.t)addFileAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))…, name=\(attachment.fileName), pool.size=\(self.pendingFileAttachments.count)")
        }
    }

    /// 按 id 移除挂起文件附件。id 不存在则 no-op。
    func removeFileAttachment(id: UUID) {
        let before = pendingFileAttachments.count
        pendingFileAttachments.removeAll { $0.id == id }
        if Self.verbose {
            Self.logger.info("\(Self.t)removeFileAttachment ➡️ id=\(id.uuidString.prefix(8))…, before=\(before), after=\(self.pendingFileAttachments.count)")
        }
    }

    /// 清空所有挂起文件附件。
    func clearFileAttachments() {
        pendingFileAttachments.removeAll()
    }
}
