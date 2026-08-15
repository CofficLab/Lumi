import CoreGraphics

/// `HorizontalScrollView` 高度测量缓存的决策单元（纯值类型，可单测）。
///
/// `NSHostingView.fittingSize` 是昂贵操作，对长代码块的全内容测量
/// 每次都可能耗掉一整帧。本类型按（内容指纹 `Fingerprint`，
/// proposal.width 的 16pt 分桶）记录最近一次测量结果：
/// - 指纹与宽度桶均一致 → 命中，调用方跳过测量；
/// - 任一变化 → 未命中，调用方重新测量后 `store` 覆盖旧值。
///
/// 契约由 `HorizontalFittingSizeCacheTests` 覆盖，对应 UI 性能审计
/// P1（docs/ui-performance-audit-2026-08.md）：流式输出期间
/// `updateNSView` 每帧被调用，只要内容指纹未变，就不应重新测量。
struct HorizontalFittingSizeCache<Fingerprint: Hashable> {

    /// 最近一次测量结果；`nil` 表示尚无缓存。
    private(set) var measured: Measured?

    struct Measured {
        /// 触发测量的内容指纹（须覆盖所有影响渲染结果的输入）。
        let fingerprint: Fingerprint
        /// proposal.width 按 16pt 分桶后的值。
        let bucketedWidth: CGFloat
        let height: CGFloat
    }

    /// proposal.width 按 16pt 分桶（16pt 一档），
    /// 容忍窗口缩放期间的小幅宽度抖动，避免每帧重新测量。
    static func bucketedWidth(for proposedWidth: CGFloat) -> CGFloat {
        (proposedWidth / 16).rounded(.down) * 16
    }

    /// 缓存命中条件：内容指纹与宽度分桶均与最近一次测量一致。
    /// 命中时返回缓存高度；未命中返回 `nil`，调用方应重新测量并 `store`。
    func cachedHeight(fingerprint: Fingerprint, proposedWidth: CGFloat) -> CGFloat? {
        guard let measured,
              measured.fingerprint == fingerprint,
              measured.bucketedWidth == Self.bucketedWidth(for: proposedWidth)
        else { return nil }
        return measured.height
    }

    /// 记录一次测量结果，覆盖旧值（同时更新指纹与宽度桶）。
    mutating func store(fingerprint: Fingerprint, proposedWidth: CGFloat, height: CGFloat) {
        measured = Measured(
            fingerprint: fingerprint,
            bucketedWidth: Self.bucketedWidth(for: proposedWidth),
            height: height
        )
    }
}
