import AppKit
import SwiftUI

/// V1 过程折叠区的**限高滚动容器**。
///
/// ## 为什么需要它
///
/// 展开后的过程区可能包含很长的 LLM 回复正文与大量工具步骤。若不设上限，
/// 一次展开就能把整屏撑满、把外层列表顶出视口，用户既看不到上下文，
/// 也无法把这条 turn 滚回视野。
///
/// ## 高度语义
///
/// 高度封顶为 ``ProcessSectionLayout/maxHeight(viewportHeight:)``（视口的 60%）：
///
/// - 内容短于上限 → 高度自适应（不补空白、无滚动条）；
/// - 内容超过上限 → 封顶并在区内垂直滚动。
///
/// 这一语义**不需要手动测量内容高度**：`ScrollView` 配合 `.frame(maxHeight:)`
/// 的固有高度就是「内容高度与上限的较小值」，而 `List` 的行高正好取这个值
/// （渲染级测试 `BoundedProcessSectionRenderTests` 锁定了这条几何事实）。
///
/// ## 为什么不自己测高
///
/// `ListV1View` 明确警告过：不要用 `GeometryReader + PreferenceKey` 测量
/// **活跃行**的高度 —— 流式 token → 高度 → 布局 → 高度 的反馈环会让
/// 列表反复重算行高。交给 SwiftUI 的固有尺寸就没有这个环。
///
/// ## 自动跟随底部（「不停在底部出现」）
///
/// 内容增长时自动把内层视口钉到底部，新内容始终出现在底部 —— 营造
/// 「agent 一直在干活」的持续工作感。
///
/// 跟随的开关是 ``isFollowing``：
///
/// - 内容增长（`documentView.frameDidChange`）→ 仍处于跟随态 → 钉底；
/// - 用户上滚（`clipView.boundsDidChange`）→ 离开底部 → **打断跟随**；
/// - 用户滚回底部 → 恢复跟随。
///
/// - Important: **不使用** SwiftUI 的 `.defaultScrollAnchor(.bottom)`。
///   实测它虽然也会在内容增长时贴底，但用户上滚后会被下一次内容增长
///   **拽回底部**，无法打断 —— 与「用户可打断」的预期冲突。
///   两个 AppKit 信号（内容增长 / 用户滚动）天然互斥，据此自行实现。
struct BoundedProcessSection<Content: View>: View {
    /// 折叠区内容。
    let content: Content

    /// 高度上限（由 ``ProcessSectionLayout`` 依据视口高度算出）。
    let maxHeight: CGFloat

    /// 内容版本号：内容变化时递增，用于重新触发初始定位。
    ///
    /// - Important: 不直接用内容本身做 identity。内容是一组 `Message`，
    ///   其相等判定与「是否增长」无关；而定位逻辑只关心
    ///   「有没有新内容进来」。
    let contentVersion: Int

    /// 是否处于「跟随底部」状态。
    ///
    /// 初始为 `true`：刚展开时用户没有表达过偏好，应当跟随新内容。
    @State private var isFollowing = true

    init(
        maxHeight: CGFloat,
        contentVersion: Int,
        @ViewBuilder content: () -> Content
    ) {
        self.maxHeight = maxHeight
        self.contentVersion = contentVersion
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(alignment: .bottom) {
                    // 底部锚点：贴底跟随时把视口滚到这里。
                    Color.clear
                        .frame(height: 1)
                        .id(ProcessSectionAnchor.bottomID)
                }
                .overlay(alignment: .bottomTrailing) {
                    // 观察器放在**内容内部**。
                    //
                    // - Important: 不能放在 `.background` 里。`.background`
                    //   的视图挂在 `ScrollView` **外面**，不在滚动视图的视图
                    //   子树中，它的 `enclosingScrollView` 恒为 `nil` ——
                    //   观察器会静默失效（实测确认）。放在内容内部时，
                    //   `enclosingScrollView` 立刻拿到 `HostingScrollView`。
                    // - Important: 零尺寸 + `allowsHitTesting(false)`，
                    //   不参与布局也不拦截点击。
                    BoundedProcessSectionScrollObserver(
                        isFollowing: isFollowing,
                        onAtBottomChange: { atBottom in
                            // 用户滚回底部 → 恢复跟随。
                            if atBottom {
                                isFollowing = true
                            }
                        },
                        onUserScrolledAway: {
                            // 用户主动上滚：打断跟随，内容不再把视口拽回底部。
                            isFollowing = false
                        }
                    )
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                }
        }
        .frame(maxHeight: maxHeight)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            // 内凹阴影：四边对称，营造「下陷」感。
            ZStack {
                // 垂直方向：上下阴影
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.12), location: 0),
                                .init(color: .black.opacity(0.04), location: 0.3),
                                .init(color: .clear, location: 0.5),
                                .init(color: .black.opacity(0.04), location: 0.7),
                                .init(color: .black.opacity(0.12), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )

                // 水平方向：左右阴影
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.12), location: 0),
                                .init(color: .black.opacity(0.04), location: 0.3),
                                .init(color: .clear, location: 0.5),
                                .init(color: .black.opacity(0.04), location: 0.7),
                                .init(color: .black.opacity(0.12), location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .overlay(
            // 内阴影：四边对称，强化凹陷感。
            VStack(spacing: 0) {
                // 顶部阴影
                LinearGradient(
                    colors: [.black.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)

                HStack(spacing: 0) {
                    // 左侧阴影
                    LinearGradient(
                        colors: [.black.opacity(0.06), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 6)

                    Spacer()

                    // 右侧阴影
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.06)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 6)
                }

                // 底部阴影
                LinearGradient(
                    colors: [.clear, .black.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(false)
        )
    }
}
