import Foundation
import MagicKit

/// 负责待发送的图片附件管理
@MainActor
final class AttachmentsVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📎"
    nonisolated static let verbose = true

    @Published private(set) var pendingAttachments: [AgentPendingImageAttachment] = []

    func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func handleImageUpload(url: URL) {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let imageData = try Data(contentsOf: url)
                let mimeType = Self.mimeTypeForPath(url.pathExtension)
                let attachment = AgentPendingImageAttachment.image(
                    id: UUID(),
                    data: imageData,
                    mimeType: mimeType,
                    url: url
                )
                await self?.add(attachment)
            } catch {
                AppLogger.core.error("\(Self.t)❌ 无法读取图片：\(error.localizedDescription)")
            }
        }
    }

    /// 取出并清空待发送附件，生成 `MessageSenderVM` 所需的 `ImageAttachment`。
    func drainPendingImageAttachments() -> [ImageAttachment] {
        let drained = pendingAttachments
        pendingAttachments.removeAll()

        return drained.compactMap { attachment in
            guard case let .image(_, data, mimeType, _) = attachment else { return nil }
            return ImageAttachment(data: data, mimeType: mimeType)
        }
    }

    // MARK: - Private

    private func add(_ attachment: AgentPendingImageAttachment) {
        pendingAttachments.append(attachment)
    }

    private nonisolated static func mimeTypeForPath(_ pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        default: return "image/jpeg"
        }
    }
}
