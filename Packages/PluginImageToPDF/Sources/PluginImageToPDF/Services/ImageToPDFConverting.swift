import Foundation

/// 单图转 PDF 后端的最小契约。
///
/// 抽出协议只为给 `ImageToPDFViewModel` 一个可注入的接缝：测试用替身确定性地
/// 驱动「转换中 → Clear → 旧任务迟到进度/完成」的时序，锁定回合身份守卫（#380）。
/// 生产实现仍是 `ImageToPDFService`。
protocol ImageToPDFConverting: Sendable {
    func convert(source: ImageItem, to outputURL: URL) -> AsyncThrowingStream<Double, Error>
}

extension ImageToPDFService: ImageToPDFConverting {}