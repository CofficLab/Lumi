import Foundation
import ProviderMessage

/// 消息图片附件（助手生成图 / 工具结果图）的解码入口。
///
/// 这些图片历史上在 SwiftUI `body` 里由计算属性解码：`isEmpty` 判定一遍、
/// 构造预览网格再一遍，工具结果的空输出分支还要第三遍（Issue #1185）。
/// 每次 body 求值都重付整段 base64 解码的 CPU 与分配开销。
///
/// 为什么复用 `ImageBase64Decoder` 而不是再建一个「按消息 id」的缓存：
/// 它按内容寻址（采样指纹分桶 + 桶内字符串比对），定位是 O(1)，且不需要
/// 额外的失效逻辑 —— 流式追加或替换会得到不同的 base64，自然落到不同条目。
/// 按 id 缓存则必须同时保存旧载荷并整串比对，才能避免读到过期图片。
enum MessageImageDecoding {
    /// 解码器注入点：生产走进程级共享缓存，测试用独立实例隔离计数。
    @TaskLocal static var decoder: ImageBase64Decoder = .shared

    /// 解码全部图片附件。
    ///
    /// 空串与非法 base64 被丢弃，与 `Data(base64Encoded:)` + `compactMap`
    /// 的既有语义一致。
    static func imageData(from attachments: [MessageImageAttachment]) -> [Data] {
        attachments.compactMap { decoder.decode($0.data) }
    }
}