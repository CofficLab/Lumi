import Foundation

/// MLX 供应商错误 → `renderKind` 映射。
///
/// 由 `MLXLumiProvider.errorRenderKind(for:)` 调用，把抛出的错误映射成
/// `MLXRenderKind` 常量，挂到错误消息上供对应渲染器识别。
enum MLXErrorHandling {
    /// 把错误映射为 renderKind。
    /// - 「模型未下载」→ `mlx-model-not-downloaded`（内联下载界面）。
    /// - 其余返回 nil：交给核心错误渲染器展示普通错误文本。
    static func renderKind(for error: Error) -> String? {
        if case InferenceError.modelNotDownloaded = error {
            return MLXRenderKind.modelNotDownloaded
        }
        return nil
    }
}
