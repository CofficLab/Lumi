import Foundation
import Combine
import KitMail

/// 撰写模式。
public enum MailComposeMode: Sendable, Equatable {
    case new
    case reply
    case forward
}

/// 撰写 ViewModel：新写/回复/转发三模式 + 本地自动保存草稿 + 发送状态机。
@MainActor
final class MailComposeViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    // 依赖
    private let composer: MailComposerService
    private let account: MailAccountConfig
    private let sessionManager: MailSessionManager

    // 模式与上下文
    let mode: MailComposeMode
    private let originalDetail: MailMessageDetail?

    // 表单
    @Published var to = ""
    @Published var cc = ""
    @Published var subject = ""
    @Published var body = ""
    @Published var attachments: [MimeAttachmentData] = []

    // 状态
    @Published private(set) var phase: Phase = .idle
    @Published var draftSavedAt: Date?

    /// 本地草稿文件路径（自动保存）。
    private var draftURL: URL? {
        let dir = MailPluginRuntime.dataDirectory()
            .appendingPathComponent("drafts", isDirectory: true)
        let key = "\(account.id.uuidString)-\(mode.key)-\(originalDetail?.summary.uid ?? 0)"
        return dir.appendingPathComponent("\(key).json")
    }

    init(
        composer: MailComposerService,
        sessionManager: MailSessionManager,
        account: MailAccountConfig,
        mode: MailComposeMode,
        originalDetail: MailMessageDetail? = nil
    ) {
        self.composer = composer
        self.sessionManager = sessionManager
        self.account = account
        self.mode = mode
        self.originalDetail = originalDetail
        applyModeDefaults()
    }

    // MARK: - 模式预填

    private func applyModeDefaults() {
        switch mode {
        case .new:
            break
        case .reply:
            guard let original = originalDetail else { return }
            if let from = original.summary.from {
                to = from.email
            }
            subject = prefix("Re:", original.summary.subject)
            body = MimeMessageBuilder.quotedReplyText(
                originalDate: original.summary.date,
                originalFrom: original.summary.from,
                originalBody: original.plainTextBody
            )
        case .forward:
            guard let original = originalDetail else { return }
            subject = prefix("Fw:", original.summary.subject)
            body = forwardQuote(original)
        }
    }

    private func prefix(_ marker: String, _ subject: String) -> String {
        guard !subject.isEmpty else { return marker }
        if subject.hasPrefix(marker) { return subject }
        return "\(marker) \(subject)"
    }

    private func forwardQuote(_ original: MailMessageDetail) -> String {
        var lines = ["---------- Forwarded message ----------"]
        if let from = original.summary.from {
            lines.append("From: \(from.rfc5322)")
        }
        lines.append("Date: \(original.summary.date.formatted(date: .long, time: .shortened))")
        lines.append("Subject: \(original.summary.subject)")
        lines.append("To: \(original.summary.to.map(\.rfc5322).joined(separator: ", "))")
        lines.append("")
        if let body = original.plainTextBody {
            lines.append(body)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 草稿自动保存

    func saveDraftNow() {
        do {
            try FileManager.default.createDirectory(
                at: draftURL!.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let payload = DraftPayload(
                mode: mode.key,
                to: to,
                cc: cc,
                subject: subject,
                body: body,
                attachments: attachments.map {
                    DraftAttachment(filename: $0.filename, mimeType: $0.mimeType, data: $0.data)
                }
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: draftURL!)
            draftSavedAt = .now
        } catch {
            // 自动保存失败不阻断编辑，静默忽略。
        }
    }

    // MARK: - 发送

    func send() {
        guard phase != .sending else { return }
        let recipients = parseAddresses(to)
        guard !recipients.isEmpty else {
            phase = .failed("收件人不能为空。")
            return
        }
        phase = .sending
        let draft = MimeMessageDraft(
            from: MailAddress(displayName: account.displayName, email: account.email),
            to: recipients,
            cc: parseAddresses(cc),
            subject: subject,
            htmlBody: nil,
            plainTextBody: body,
            attachments: attachments,
            inReplyTo: originalDetail?.summary.messageID,
            references: originalDetail.map {
                MimeMessageBuilder.replyReferences(
                    originalReferences: $0.summary.references,
                    originalMessageID: $0.summary.messageID
                )
            } ?? []
        )
        Task {
            do {
                try await composer.send(draft: draft, account: account)
                phase = .sent
                clearLocalDraft()
            } catch let error as MailError {
                phase = .failed(error.localizedDescription)
                saveDraftNow() // 失败保留草稿
            } catch {
                phase = .failed(error.localizedDescription)
                saveDraftNow()
            }
        }
    }

    /// 添加附件（拖入/选择）。
    func addAttachment(_ data: Data, filename: String) {
        attachments.append(
            MimeAttachmentData(
                filename: filename,
                mimeType: mimeType(for: filename),
                data: data
            )
        )
        saveDraftNow()
    }

    func removeAttachment(at index: Int) {
        guard attachments.indices.contains(index) else { return }
        attachments.remove(at: index)
        saveDraftNow()
    }

    // MARK: - 工具

    private func parseAddresses(_ raw: String) -> [MailAddress] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { MailAddress(displayName: nil, email: String($0)) }
    }

    private func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "txt": return "text/plain"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }

    private func clearLocalDraft() {
        if let url = draftURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - 本地草稿序列化

private extension MailComposeMode {
    var key: String {
        switch self {
        case .new: return "new"
        case .reply: return "reply"
        case .forward: return "forward"
        }
    }
}

private struct DraftAttachment: Codable {
    var filename: String
    var mimeType: String
    var data: Data
}

private struct DraftPayload: Codable {
    var mode: String
    var to: String
    var cc: String
    var subject: String
    var body: String
    var attachments: [DraftAttachment]
}
