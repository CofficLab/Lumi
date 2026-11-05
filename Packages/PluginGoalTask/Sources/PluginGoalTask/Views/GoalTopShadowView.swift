import LumiUI
import SwiftUI

/// Goal 面板顶边向上投射的柔和阴影。
///
/// ## 为什么不是一条线性渐变带
///
/// 最初这里用的是「12pt 高的线性渐变带 + `.offset` 推到面板之外」:
/// 紧贴顶边最实、向上线性衰减为透明。它有两个问题:
///
/// 1. **渐变是线性的**,衰减速率恒定,于是阴影带的上沿是一条肉眼可见的
///    直边——像一条贴上去的灰条,而不是光影。
/// 2. **顶部一端直接落到全透明**,透明边界与下方实心阴影之间没有过渡,
///    形成一条硬边。
///
/// 面板下方任务列表容器的阴影(`taskListSurface`)用的是「模糊挖空」:
/// 阴影的边界由高斯模糊产生,天然没有硬边,观感柔和很多。
/// 这里的实现刻意与之**同源**,让面板上下两处阴影读起来是一套东西。
///
/// ## 实现
///
/// 与 `taskListSurface` 完全相反的方向:任务列表把**中心**挖掉,得到一圈
/// 向内衰减的环;这里把**顶端**挖掉,得到一条向上衰减的带。
///
/// - 先用阴影色铺满整条带;
/// - 再在合成组里用一块「内缩 + 模糊」的黑色形状以 `destinationOut`
///   挖掉顶端一段;
/// - 剩下的就是紧贴面板顶边最实、向上经高斯衰减为透明的阴影。
///
/// 挖空形状的高度比「实心核心」多出一个模糊半径,正是这个多出来的部分
/// 决定了顶端渐隐的柔和程度。
///
/// 不直接改 `LumiUI` 的共享令牌:`DesignTokens.Shadow` 里的令牌同时作用于
/// 全站输入框与工具栏,动它会波及整个 App 的观感。模糊半径与不透明度沿用
/// 本插件自己的取值,只把「挖空方向」这一处差异留在插件内部。
struct GoalTopShadowView: View {
    /// 阴影带的高度(点):自面板顶边向上扩散的覆盖范围。
    ///
    /// 20pt 足够让「面板浮在聊天区之上」的层次读得出来,又不至于糊到上方
    /// 消息列表的内容上。
    static let bandHeight: CGFloat = 20

    /// 阴影的不透明度:暗色主题下同样的黑色几乎看不出层次,故暗色更重。
    let opacity: Double

    /// 高斯模糊半径:决定顶端渐隐的柔和程度,也是阴影带的视觉厚度来源。
    let blurRadius: CGFloat

    /// 紧贴面板顶边的实心核心高度(点)。
    ///
    /// 核心保持实色,让阴影在顶边处有明确的「接触感」;核心之外的区域
    /// 交给模糊去衰减。核心太厚会退回生硬的线性观感,太薄则失去层次。
    let coreHeight: CGFloat

    init(opacity: Double, blurRadius: CGFloat, coreHeight: CGFloat) {
        self.opacity = opacity
        self.blurRadius = blurRadius
        self.coreHeight = coreHeight
    }

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(opacity))
            .frame(height: Self.bandHeight)
            .mask {
                Rectangle()
                    .fill(Color.white)
                    .overlay(
                        Rectangle()
                            .fill(Color.black)
                            // 挖空范围 = 核心之外的部分 + 一个模糊半径。
                            // 多出来的这一段模糊半径正是顶端柔和过渡的来源:
                            // 若刚好挖到核心边界,顶端会是一条硬边。
                            .frame(height: Self.bandHeight - coreHeight + blurRadius)
                            .offset(y: -(Self.bandHeight - coreHeight))
                            .blur(radius: blurRadius)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            }
            // 上移到面板顶边之外:阴影要「压」在上方的内容上,而不是落在面板内部。
            .offset(y: -Self.bandHeight)
            .allowsHitTesting(false)
    }
}
