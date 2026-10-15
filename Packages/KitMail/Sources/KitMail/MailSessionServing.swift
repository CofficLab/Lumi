import Foundation

/// 邮件会话薄抽象：KitMail 对协议栈的唯一依赖面。
///
/// 设计约束（见 docs/plans/2026-10-01-mail-client-plugin.md 第 5 节）：
/// - 上层（PluginMail）只依赖本协议，不触碰任何第三方类型；
/// - 实现可替换：`MailCoreAdapter`（A）／ swift-nio-imap + 自建 SMTP（B）／
///   自实现最小协议子集（C），切换不影响上层；
/// - 并发：实现方负责线程安全（actor 或串行队列），UI 层只消费发布状态。
public protocol MailSessionServing: Sendable {
    /// 建立连接（IMAP）。认证失败抛 `.authFailed`，网络不可达抛 `.network`。
    /// 实现应内部重试/超时（30s），调用方按需在 UI 层展示可读错误。
    func connect() async throws

    /// 断开连接（幂等）。
    func disconnect() async

    /// 列出全部文件夹（含未读数，若协议栈支持）。
    func listFolders() async throws -> [MailFolder]

    /// 拉取文件夹内邮件摘要。
    /// - Parameters:
    ///   - folder: 文件夹路径
    ///   - sinceUID: 增量游标（仅拉取 uid > sinceUID 的新邮件；nil 表示从头拉取）
    ///   - limit: 最多条数（倒序取最新 N 条；增量同步时忽略）
    func fetchMessages(folder: String, sinceUID: UInt64?, limit: Int) async throws -> [MailMessageSummary]

    /// 拉取单封邮件正文与附件。附件默认落盘（`MailAttachment.localFileURL`）。
    func fetchBody(uid: UInt64, folder: String) async throws -> MailMessageDetail

    /// 修改邮件标记（已读 / 星标）。任一参数为 nil 表示不修改该标记。
    func setFlags(uid: UInt64, folder: String, isRead: Bool?, isFlagged: Bool?) async throws

    /// 按关键字搜索文件夹内的邮件，返回匹配的 uid 列表。
    func search(query: String, folder: String) async throws -> [UInt64]

    /// 通过 SMTP 发送邮件（`mime` 为完整 RFC 5322 原始字节）。
    func sendMessage(mime: Data) async throws

    /// 追加草稿到服务器端草稿文件夹（失败降级：仅本地记录，不阻断成功态）。
    func appendDraft(mime: Data, folder: String) async throws
}

/// 会话工厂：由账户配置 + 凭据创建会话。
///
/// 凭据（密码 / refresh token）只存在于创建会话的瞬间，不落盘、不进日志。
public protocol MailSessionFactory: Sendable {
    func makeSession(account: MailAccountConfig, password: String) async throws -> any MailSessionServing
}
