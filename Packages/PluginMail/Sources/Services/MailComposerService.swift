import Foundation
import KitMail

/// 邮件发送编排。
///
/// 流程（计划 Task 4.2）：MimeMessageBuilder → SMTP 发送 →
/// 成功后 IMAP APPEND 到已发送文件夹（失败降级：仅本地记录，不阻断成功态）。
public actor MailComposerService {
    private let sessionManager: MailSessionManager

    public init(sessionManager: MailSessionManager) {
        self.sessionManager = sessionManager
    }

    /// 发送一封邮件。成功返回（已尝试归档到 Sent）；失败抛 `MailError`。
    ///
    /// - Parameters:
    ///   - draft: 待发送 MIME 草稿（KitMail 值类型）。
    ///   - account: 发件账户（`from` 必须与账户邮箱一致）。
    public func send(
        draft: MimeMessageDraft,
        account: MailAccountConfig
    ) async throws {
        guard let password = MailAccountStore.password(for: account.id) else {
            throw MailError.authFailed
        }
        let mime = try MimeMessageBuilder.build(draft)
        let session = try await sessionManager.session(for: account)
        do {
            try await session.sendMessage(mime: mime)
        } catch let error as MailError {
            throw error
        } catch {
            throw MailError.protocolError("发送失败：\(error.localizedDescription)")
        }

        // 归档到已发送：失败降级（不阻断成功态，仅日志记录）。
        do {
            let sentFolder = await sentFolderPath(session: session)
            try await session.appendDraft(mime: mime, folder: sentFolder)
        } catch {
            // 归档失败不影响发送成功；由调用方日志记录。
        }
    }

    /// 保存草稿到服务器 Drafts（可选，供自动保存）。
    public func appendDraft(
        draft: MimeMessageDraft,
        account: MailAccountConfig
    ) async throws {
        guard let password = MailAccountStore.password(for: account.id) else {
            throw MailError.authFailed
        }
        let mime = try MimeMessageBuilder.build(draft)
        let session = try await sessionManager.session(for: account)
        let draftsFolder = await draftsFolderPath(session: session)
        try await session.appendDraft(mime: mime, folder: draftsFolder)
    }

    // MARK: - 已发送/草稿文件夹探测

    private func sentFolderPath(session: any MailSessionServing) async -> String {
        let folders = (try? await session.listFolders()) ?? []
        return folders.first { $0.kind == .sent }?.path ?? "Sent"
    }

    private func draftsFolderPath(session: any MailSessionServing) async -> String {
        let folders = (try? await session.listFolders()) ?? []
        return folders.first { $0.kind == .drafts }?.path ?? "Drafts"
    }
}
