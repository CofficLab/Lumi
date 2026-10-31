import LumiUI
import SwiftUI

/// 任务列表容器的「凹陷」内阴影,与 `LumiUI.appInputSurface` 唯一的区别是**上下对称**。
///
/// `appInputSurface` 模拟的是「上方来光」:挖空块整体向下偏移
/// (`DesignTokens.Shadow.innerFieldOffsetY`),于是顶边留下完整阴影带,
/// 而底边被挖空块完全覆盖,阴影几乎为零。任务列表是个封闭容器而不是输入框,
/// 底边没有承托它的后续内容,缺了阴影会让人误以为列表在那里被一刀切断,
/// 因此这里改成上下各内缩同样的距离,让底边获得与顶边等强度的阴影。
///
/// 没有直接改 `LumiUI` 的共享令牌:`innerFieldOffsetY` / `innerFieldOpacity`
/// 同时作用于 `AppInputField`、`AppFocusableInputField`、`GlassTextField`、
/// `AppSearchBar` 等输入框,动它会波及全站输入框的观感。模糊半径与不透明度
/// 仍然复用共享令牌,只把「挖空方式」这一处差异留在插件内部。
///
/// 实现沿用 CSS `inset` 阴影的做法:整块填阴影色,再用一块
/// 「内缩 + 模糊」的同形圆角矩形以 `destinationOut` 挖掉中心,
/// 剩下的就是从边缘向内衰减的环形。
struct TaskListSurfaceModifier: ViewModifier {
    /// 与底层形状一致的圆角,确保内阴影贴合容器边缘。
    let cornerRadius: CGFloat

    /// 挖空块相对容器上下边缘的内缩量,决定上下阴影带的厚度。
    ///
    /// 取值与 `DesignTokens.Shadow.innerFieldOffsetY` 一致,
    /// 这样顶边的观感与改造前完全一致,变化只发生在底边。
    private static let verticalInset: CGFloat = 2

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let shadowColor = Color.black.opacity(DesignTokens.Shadow.innerFieldOpacity)

        content
            .overlay(
                shape
                    .fill(shadowColor)
                    .mask(
                        Rectangle()
                            .fill(Color.white)
                            .overlay(
                                shape
                                    .fill(Color.black)
                                    // 上下各内缩,而不是整体下移:挖空块不再越过底边,
                                    // 底边因此保留一条与顶边等厚的阴影带。
                                    .padding(.vertical, Self.verticalInset)
                                    .blur(radius: DesignTokens.Shadow.innerFieldBlur)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )
                    .clipShape(shape)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    /// 给任务列表容器叠一层上下对称的凹陷内阴影。
    ///
    /// - Parameter cornerRadius: 与底层形状一致的圆角,确保内阴影贴合边缘。
    func taskListSurface(cornerRadius: CGFloat) -> some View {
        modifier(TaskListSurfaceModifier(cornerRadius: cornerRadius))
    }
}
