import LumiUI
import SwiftUI

/// Goal 面板顶边向上投射的柔和阴影。
///
/// ## 形状契约
///
/// 一道真实的投影有两个可测量的特征:
///
/// 1. **接触处最浓,向上单调变淡**——面板边缘挡住光,阴影紧贴边缘最浓,
///    往上按高斯衰减。斜率在接触处最陡。
/// 2. **贴着面板有一条实心接触线**——面板顶边处不该是半透明的,那里是
///    阴影浓度最高的地方。
///
/// 横向还有第三个特征:
///
/// 3. **两端自然淡出**——阴影是面板投出来的光影,不该是一条齐刷刷切到
///    屏幕边缘的矩形色带。
///
/// ## 为什么是渐变遮罩而不是「模糊挖空」
///
/// 早期实现是:填一层阴影色,再用一块「顶端对齐 + 向上溢出」的黑色形状
/// 以 `destinationOut` 挖掉顶端,靠 `.blur()` 让挖空边界变软。
///
/// 这条路走不通,因为 `.blur()` 作用在**挖空块自己**身上:模糊会同时向上
/// 和向下扩散,向下的一半正好侵入核心区,把本该实心的接触线削掉。
/// 实测(黑底渲染遮罩本体)核心区保留率只有 0.55~0.81,于是剖面变成
/// 「中间鼓、两头平」——阴影浮在面板上方,而不是面板压出来的。
///
/// 现在直接用 `LinearGradient` 采样高斯函数作为遮罩:核心区显式给 alpha=1,
/// 其余部分按 `exp(-0.5·(x/σ)²)` 衰减。形状由数学直接决定,不再依赖
/// 「模糊+挖空」的交互,也不会再被别的渲染细节带偏。
///
/// ## 参数
///
/// - `bandHeight`:阴影带的总高度(垂直方向)。
/// - `sigma`:高斯衰减的标准差,决定渐隐的柔和程度与阴影的视觉厚度。
/// - `coreHeight`:紧贴面板顶边的实心接触线高度。
/// - `horizontalFadeWidth`:横向两端淡出的宽度。面板本身是满宽的
///   (`.frame(maxWidth: .infinity)`),若阴影不做横向羽化,两端就会撞上
///   屏幕边缘形成垂直硬边,读起来像一条横贯屏幕的灰带。
struct GoalTopShadowView: View {
    /// 阴影带的高度(点):自面板顶边向上扩散的覆盖范围。
    ///
    /// 8pt 足够让「面板浮在聊天区之上」的层次读得出来,又不至于糊到上方
    /// 消息列表的内容上。更早的版本用 20pt,实测整条带都被阴影填满,读起来
    /// 是「一大片灰压在上方」;后来收到 12pt,但剖面形状不对,看起来仍像一条
    /// 贴上去的灰带。
    static let bandHeight: CGFloat = 8

    /// 阴影的不透明度:暗色主题下同样的黑色几乎看不出层次,故暗色更重。
    let opacity: Double

    /// 高斯衰减的标准差(点):决定渐隐的柔和程度与阴影的视觉厚度。
    let sigma: CGFloat

    /// 紧贴面板顶边的实心接触线高度(点)。
    ///
    /// 暴露为静态常量,便于测试直接按它切分「接触线」与「衰减区」。
    static let coreHeight: CGFloat = 1.5

    /// 横向两端淡出的宽度(点)。
    ///
    /// 阴影从面板中部向两侧渐隐,到边缘时归零,避免齐刷刷切在屏幕边上。
    static let horizontalFadeWidth: CGFloat = 48

    init(opacity: Double, sigma: CGFloat) {
        self.opacity = opacity
        self.sigma = sigma
    }

    /// 阴影遮罩的高斯采样点(垂直方向)。
    ///
    /// `LinearGradient` 的 `location=0` 对应 `startPoint`(此处 `.top`,即带顶),
    /// `location=1` 对应 `endPoint`(`.bottom`,即带底 = 面板顶边)。
    ///
    /// 因此:
    /// - `t ∈ [1 - coreFraction, 1]` 是实心接触线,alpha 固定为 1;
    /// - `t < 1 - coreFraction` 是衰减区,alpha 按到核心上沿的距离做高斯衰减。
    ///
    /// 采样点取各区间中心 `(i + 0.5) / (n + 1)` 而不是 `i / n`:后者会让
    /// 最顶行正好落在 `location = 0` 上,而 LinearGradient 在 `location = 0`
    /// 处只取首 stop 的颜色,量化后容易整行塌成 0,带顶那一行就被削掉了。
    private var verticalStops: [Gradient.Stop] {
        let sampleCount = 32
        let coreFraction = Self.coreHeight / Self.bandHeight

        return (0...sampleCount).map { index in
            let t = (CGFloat(index) + 0.5) / CGFloat(sampleCount + 1)
            let alpha: Double
            if t >= 1 - coreFraction {
                // 实心接触线:阴影在此处保持满浓度。
                alpha = 1.0
            } else {
                // 到核心上沿的距离(点),按高斯尾部衰减。
                let distance = (1 - coreFraction - t) * Self.bandHeight
                alpha = exp(-0.5 * pow(distance / sigma, 2))
            }
            return Gradient.Stop(color: Color.white.opacity(alpha), location: Double(t))
        }
    }

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(opacity))
            .frame(height: Self.bandHeight)
            .mask {
                // 垂直方向:高斯衰减 + 实心接触线。
                LinearGradient(
                    stops: verticalStops,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            // 横向:两端淡出,避免阴影以垂直硬边切在屏幕边上。
            .mask {
                LinearGradient(
                    stops: horizontalStops,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            // 上移到面板顶边之外:阴影要「压」在上方的内容上,而不是落在面板内部。
            .offset(y: -Self.bandHeight)
            .allowsHitTesting(false)
    }

    /// 横向羽化的采样点。
    ///
    /// 面板是满宽的,阴影两端若直接截止会形成垂直硬边。这里让 alpha 在
    /// 靠近两端的一个宽度内线性淡出到 0,中间保持满浓度。
    private var horizontalStops: [Gradient.Stop] {
        [
            Gradient.Stop(color: Color.white.opacity(0), location: 0),
            Gradient.Stop(color: Color.white.opacity(1), location: Self.horizontalFadeFraction),
            Gradient.Stop(color: Color.white.opacity(1), location: 1 - Self.horizontalFadeFraction),
            Gradient.Stop(color: Color.white.opacity(0), location: 1),
        ]
    }

    /// 横向淡出区占整个宽度的比例。
    ///
    /// 面板宽度是运行时才知道的(`.frame(maxWidth: .infinity)`),所以这里
    /// 用「按比例」而不是「按点数」的方式表达淡出:两端各占 12% 的宽度,
    /// 视觉上与固定点数接近,但不会被窄面板压缩成一条缝。
    private static let horizontalFadeFraction: Double = 0.12
}
