import Foundation
import ProviderMessageSender

/// 待发队列的持久化存储（#596）。
///
/// 会话忙碌时提交的消息只进入内存 `pendingQueues`，输入框却已清空；退出前
/// 若不落盘，重启后这些已提交的内容与附件彻底丢失。本存储把队列快照写入
/// Application Support 下的 JSON 文件，启动时恢复，保证「已提交」不静默丢失。
struct PendingQueueStore {
    let fileURL: URL

    init(fileURL: URL = PendingQueueStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    /// 生产环境落盘位置：`Application Support/com.coffic.Lumi/MessageSender/pending-queues.json`。
    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
            .appendingPathComponent("MessageSender", isDirectory: true)
            .appendingPathComponent("pending-queues.json")
    }

    /// 读取持久化的待发消息；文件不存在或损坏时返回空数组，不阻断启动。
    func load() -> [PendingChatMessage] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PendingChatMessage].self, from: data)) ?? []
    }

    /// 原子写入队列快照。空队列删除文件，避免残留过期内容在下次启动被误恢复。
    /// 写入失败抛出，由调用方记录——不得把落盘失败静默当作成功（#596）。
    func save(_ messages: [PendingChatMessage]) throws {
        let fileManager = FileManager.default
        if messages.isEmpty {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            return
        }
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(messages)
        try data.write(to: fileURL, options: .atomic)
    }
}