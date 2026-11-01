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
struct BoundedProcessSection<Content: View>: View {
    /// 折叠区内容。
    let content: Content

    /// 高度上限（由 ``ProcessSectionLayout`` 依据视口高度算出）。
    let maxHeight: CGFloat

    /// 内容版本号：内容变化时递增，用于触发贴底跟随。
    ///
    /// - Important: 不直接用内容本身做 identity。内容是一组 `Message`，
    ///   其相等判定与「是否增长」无关；而跟随逻辑只关心
    ///   「有没有新内容进来」。
    let contentVersion: Int

    /// 用户是否正停在底部。`false` 表示用户主动上滚过，跟随被打断。
    @State private var isPinnedToBottom = true

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
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignment: .bottom) {
                        // 底部锚点：贴底跟随时把视口滚到这里。
                        Color.clear
                            .frame(height: 1)
                            .id(ProcessSectionAnchor.bottomID)
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
            .background {
                // 观察内层滚动位置，判定「是否贴底」；同时把内层滚动视图
                // 注册到接力表（内层到底时把剩余增量转给外层列表）。
                BoundedProcessSectionScrollObserver(
                    onAtBottomChange: { atBottom in
                        isPinnedToBottom = atBottom
                    },
                    onUserScrolledAway: {
                        // 用户主动上滚：打断贴底跟随。
                        isPinnedToBottom = false
                    }
                )
            }
            .onChange(of: contentVersion) { _, _ in
                followBottomIfNeeded(proxy: proxy)
            }
        }
    }

    /// 内容增长后，若用户仍停在底部则跟随到新的底部。
    ///
    /// - Important: 跟随的开关完全由「是否贴底」决定：用户一旦主动上滚
    ///   （`isPinnedToBottom` 变 false），后续内容增长就不再拽他回底部；
    ///   等他手动滚回底部，跟随自动恢复。
    private func followBottomIfNeeded(proxy: ScrollViewProxy) {
        guard isPinnedToBottom else { return }
        proxy.scrollTo(ProcessSectionAnchor.bottomID, anchor: .bottom)
    }
}
