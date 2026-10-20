import LumiUI
import SwiftUI

/// SidebarView 中展示的任务列表与单行渲染。
///
/// 行高采用 `SidebarView.rowHeight`(公开为 `internal`),便于主视图计算总高。
/// 列表高度由调用方通过 `frame(height:)` 传入,本组件只负责内容布局。
struct SidebarTaskList: View {
    let tasks: [GoalTaskDisplayItem]

    /// 列表容器圆角,用于让内阴影贴合容器边缘。
    private static let containerCornerRadius: CGFloat = 8

    /// 列表容器与外层面板之间的左右留白。
    ///
    /// 容器贴着面板边缘时,内阴影形成的描边会和面板分隔线连成一条线,
    /// 两侧的圆角也会被裁掉,看起来像「贴边」而不是独立面板。
    /// 留出一段固定内边距后,容器轮廓完整,左右两侧都有呼吸空间。
    private static let containerHorizontalInset: CGFloat = 12

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(tasks) { task in
                    TaskRowView(displayItem: task)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        // 让列表容器呈现「凹陷」质感:四周向内衰减的阴影,
        // 复用 LumiUI 的输入面内阴影令牌,避免各插件各写一套内阴影。
        .appInputSurface(cornerRadius: Self.containerCornerRadius)
        // 与外层面板拉开距离,让容器左右两侧的圆角与内阴影完整可见。
        // 放在 appInputSurface 之后,保证内阴影仍贴合缩小后的容器边缘。
        .padding(.horizontal, Self.containerHorizontalInset)
    }
}

/// 单个任务行:状态图标 + 标题 + 可选并行组标签。
///
/// 标记 `internal` 而非 `fileprivate`,因为它是 `SidebarTaskList` 公开 API
/// 的一部分,允许其他模块(若有需要)单独渲染一个任务行。
struct TaskRowView: View {
    let displayItem: GoalTaskDisplayItem

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: displayItem.statusSystemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(displayItem.statusColor)
                .frame(width: 14)

            Text(displayItem.title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)

            if let group = displayItem.parallelGroup {
                Text(String(format: pluginLocalization.string("[%@]"), group))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: SidebarView.rowHeight)
        .background(Color.orange.opacity(0.075))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}