import Foundation

/// 视频转换后端的最小契约。
///
/// 抽出协议只为给 `VideoConverterViewModel` 一个可注入的接缝：测试用替身
/// 确定性地驱动「转换中 → 切换选择 → 旧任务迟到回调」的时序，锁定回合身份
/// 守卫（#263）。生产实现仍是 `VideoConverterService`。
protocol VideoConverting: Sendable {
    func convert(
        input: URL,
        output: URL,
        format: VideoFormat,
        onProgress: @escaping @Sendable (Double) -> Void,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws
    func cancel() async
}

extension VideoConverterService: VideoConverting {}