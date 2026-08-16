import LumiUI
import SwiftUI

/// 对话列表骨架屏加载视图
///
/// 模拟 `ItemView` 的布局结构，展示标题、副标题和元数据三行占位色块，
/// 配合 shimmer 扫光动画，提供更自然的加载体验。
struct ListLoadingView: View {
    @LumiTheme private var theme: any LumiUITheme

    /// 每行骨架的宽度比例（标题 / 副标题 / 元数据），用于制造视觉差异
    private let rowConfigs: [(title: CGFloat, subtitle: CGFloat, meta: CGFloat)] = [
        (0.78, 0.52, 0.36),
        (0.62, 0.58, 0.42),
        (0.84, 0.46, 0.33),
        (0.70, 0.55, 0.39),
        (0.56, 0.50, 0.35),
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rowConfigs.indices, id: \.self) { index in
                SkeletonRow(
                    titleWidthRatio: rowConfigs[index].title,
                    subtitleWidthRatio: rowConfigs[index].subtitle,
                    metaWidthRatio: rowConfigs[index].meta,
                    baseColor: theme.textSecondary
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - SkeletonRow

/// 单行骨架占位视图，模拟 `ItemView` 的三行文本布局
private struct SkeletonRow: View {
    let titleWidthRatio: CGFloat
    let subtitleWidthRatio: CGFloat
    let metaWidthRatio: CGFloat
    let baseColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 标题 — 对应 .appMicroEmphasized (11pt)
            SkeletonBar(
                height: 11,
                widthRatio: titleWidthRatio,
                baseColor: baseColor
            )

            // 副标题（provider · model）— 对应 .footnote (13pt)
            SkeletonBar(
                height: 9,
                widthRatio: subtitleWidthRatio,
                baseColor: baseColor
            )

            // 元数据（project · time）— 对应 .footnote (13pt)
            SkeletonBar(
                height: 9,
                widthRatio: metaWidthRatio,
                baseColor: baseColor
            )
        }
        .padding(.horizontal, 16) // AppUI.Spacing.md
        .padding(.vertical, 8) // AppUI.Spacing.sm
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(baseColor.opacity(0.05))
    }
}

// MARK: - SkeletonBar

/// 单个骨架色块 + shimmer 扫光
private struct SkeletonBar: View {
    let height: CGFloat
    let widthRatio: CGFloat
    let baseColor: Color

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(baseColor.opacity(0.08))
                .frame(
                    width: proxy.size.width * widthRatio,
                    height: height
                )
                .shimmer(isActive: true)
        }
        .frame(height: height)
    }
}
