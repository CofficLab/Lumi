import Foundation
import KitMail

/// 草稿的文本部分：很小，每次编辑都会重写。
struct MailDraftPayload: Codable, Sendable {
    var mode: String
    var to: String
    var cc: String
    var subject: String
    var body: String
    /// 旧版本把附件字节内嵌在草稿 JSON 里。只为读取历史草稿保留，写出时始终为 nil。
    var attachments: [MailDraftAttachment]?
}

/// 草稿的附件部分：单独落盘，只有附件集合变化时才重新编码（见 issue #1188）。
struct MailDraftAttachment: Codable, Sendable {
    var filename: String
    var mimeType: String
    var data: Data
}

/// 一次自动保存的不可变快照，值类型可安全跨 actor 传递。
struct MailDraftSnapshot: Sendable {
    var textURL: URL
    var attachmentsURL: URL
    var payload: MailDraftPayload
    var attachments: [MailDraftAttachment]
    /// 附件集合的版本号，只在增删附件时递增。
    var attachmentsRevision: Int
}

/// 草稿落盘边界，便于测试注入门闩/线程记录替身。
protocol MailDraftSaving: Sendable {
    /// 写入快照；generation 落后于已写入的快照时丢弃，返回 false。
    func save(_ snapshot: MailDraftSnapshot, generation: Int) async throws -> Bool
    /// 删除草稿（文本 + 附件），并丢弃 generation 之前的在途写入。
    func discard(textURL: URL, attachmentsURL: URL, generation: Int) async
}

/// 草稿落盘 actor：JSON 编码与文件 IO 全部在主线程之外串行执行。
actor MailDraftStore: MailDraftSaving {
    private var lastGeneration = 0
    private var savedAttachmentsRevision: Int?

    /// - Parameter restoredAttachmentsRevision: 恢复历史草稿时磁盘上已有的附件版本，
    ///   传入后首次纯文本编辑不会重写附件文件。
    init(restoredAttachmentsRevision: Int? = nil) {
        self.savedAttachmentsRevision = restoredAttachmentsRevision
    }

    func save(_ snapshot: MailDraftSnapshot, generation: Int) throws -> Bool {
        guard generation > lastGeneration else { return false }
        lastGeneration = generation
        try Self.write(snapshot, previousAttachmentsRevision: savedAttachmentsRevision)
        savedAttachmentsRevision = snapshot.attachmentsRevision
        return true
    }

    func discard(textURL: URL, attachmentsURL: URL, generation: Int) {
        lastGeneration = max(lastGeneration, generation)
        savedAttachmentsRevision = nil
        try? FileManager.default.removeItem(at: textURL)
        try? FileManager.default.removeItem(at: attachmentsURL)
    }

    /// 同步的编码与写入实现，只在 actor 的执行器上被调用。
    nonisolated static func write(
        _ snapshot: MailDraftSnapshot,
        previousAttachmentsRevision: Int?
    ) throws {
        try FileManager.default.createDirectory(
            at: snapshot.textURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if snapshot.attachmentsRevision != previousAttachmentsRevision {
            let attachmentData = try JSONEncoder().encode(snapshot.attachments)
            try attachmentData.write(to: snapshot.attachmentsURL, options: .atomic)
        }
        let textData = try JSONEncoder().encode(snapshot.payload)
        try textData.write(to: snapshot.textURL, options: .atomic)
    }
}
