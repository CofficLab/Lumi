import Foundation
import KitLLM

/// 会话级图片临时文件。
///
/// `ChatSession` 会把带图消息保留在 transcript 中，命中的后续轮次仍可能
/// 依据这些 URL 重新渲染提示词，因此文件必须在整个会话生命周期内可读，
/// 不能像一次性请求那样生成结束就删除。
final class MLXSessionImageStore {

    let directory: URL
    private var writtenNames: Set<String> = []

    private init(directory: URL) {
        self.directory = directory
    }

    static func make() throws -> MLXSessionImageStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-mlx-session-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return MLXSessionImageStore(directory: directory)
    }

    /// 为 `messages` 中的图片写临时文件。
    ///
    /// - Parameters:
    ///   - messages: 需要建消息的切片。
    ///   - startIndex: 切片首元素在完整历史中的下标；文件名以它为基准，
    ///     保证多轮追加时同一张图始终对应同一个文件。
    /// - Returns: 以切片内下标为键的图片 URL 表，供 `MLXChatMessages.build` 使用。
    func makeImageURLs(
        messages: ArraySlice<LLMMessage>,
        startingAt startIndex: Int
    ) throws -> [Int: [URL]] {
        var result: [Int: [URL]] = [:]
        for (offset, message) in messages.enumerated() where message.role == .user {
            let globalIndex = startIndex + offset
            let urls = try message.images.enumerated().map { imageIndex, image -> URL in
                let ext = image.mimeType.lowercased().contains("png") ? "png" : "jpg"
                let name = "\(globalIndex)-\(imageIndex).\(ext)"
                let url = directory.appendingPathComponent(name)
                if !writtenNames.contains(name) {
                    try image.data.write(to: url, options: .atomic)
                    writtenNames.insert(name)
                }
                return url
            }
            if !urls.isEmpty {
                result[offset] = urls
            }
        }
        return result
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}