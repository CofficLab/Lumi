import Foundation

/// MarkdownKit 渲染缓存的公开预热入口。
///
/// 消息列表等宿主在会话加载完成后,应在后台线程(如 `Task.detached`,
/// utility 优先级)对窗口内的消息内容批量调用 `warm(markdown:)`,
/// 使后续滚动到未物化过的行时块级缓存同步命中 —— 行首帧即有内容与
/// 测量高度,不触发主线程解析,也不出现"留空 → 填充"的两阶段高度跳变。
///
/// 线程安全;重复预热同一内容为一次近免费的缓存查询。
public enum MarkdownRenderCache {

    /// 解析并写入块级渲染缓存(若未缓存)。应在后台线程调用。
    public static func warm(markdown: String) {
        guard !markdown.isEmpty else { return }
        MarkdownBlockCache.shared.warm(markdown: markdown)
    }
}
