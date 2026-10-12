// KitMail
// 邮件协议栈包：只依赖开放协议（IMAP/SMTP），不绑定任何厂商 API。
//
// 结构：
// - MailModels          账户/文件夹/邮件摘要/正文/附件/地址 模型（Sendable + Codable）
// - MailSessionServing  薄抽象协议（连接/文件夹/取信/标记/搜索/发信）
// - MailCoreAdapter     MailCore2 适配器（唯一 import 第三方处）
// - MimeMessageBuilder  撰写：纯文本/HTML multipart、附件、引用回复
// - MailError           统一错误（auth/network/protocol/notFound/offline）
//
// 边界：本包不依赖任何插件与内核；MailCore2 第三方类型不得泄漏出本包。

public struct KitMail {
    public init() {}
}
