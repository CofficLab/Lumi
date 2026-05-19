import Foundation
import MagicKit

///
/// ## 初始化规则
///
/// 由 `WindowScope` 持有，通过 `.environmentObject()` 注入。nView 通过 `@EnvironmentObject var agentAttachmentsVM: WindowAttachmentsVM` 访问。
/// 负责待发送的图片附件管理
///
/// ## 初始化规则
///
/// 由 `WindowScope` 持有并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var agentAttachmentsVM: WindowAttachmentsVM` 访问。
@MainActor
final class WindowAttachmentsVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📎"
    nonisolated static let verbose: Bool = false
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

    func handleScreenshotData(_ data: Data) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let url = URL(fileURLWithPath: "/screenshot_\(timestamp).png")
        add(.image(id: UUID(), data: data, mimeType: "image/png", url: url))
    }

    /// 取出并清空待发送附件，生成发送流程所需的 `ImageAttachment`。
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
