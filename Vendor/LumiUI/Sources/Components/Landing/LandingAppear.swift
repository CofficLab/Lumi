import SwiftUI

/// 落地页入场动画:内容出现时由下方淡入上浮并轻微放大,按 `delay` 错峰。
///
/// 自动尊重「减弱动态效果」(`@LumiMotionPreferenceReader`):当用户开启
/// 减弱动效或系统禁用动画时,内容会立即显示而不播放过渡。
///
/// 搭配分阶(stagger)使用:为不同区块传入递增的 `delay`
/// (例如 `Double(index) * 0.06`)即可得到依次入场的效果。
public struct LandingAppear: ViewModifier {
    @LumiMotionPreferenceReader private var motionPreference

    private let delay: Double
    @State private var shown = false

    public init(delay: Double = 0) {
        self.delay = delay
    }

    public func body(content: Content) -> some View {
        let animated = motionPreference.allowsMotion
        return content
            .opacity(animated ? (shown ? 1 : 0) : 1)
            .offset(y: animated ? (shown ? 0 : 16) : 0)
            .scaleEffect(animated ? (shown ? 1 : 0.97) : 1, anchor: .top)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeOut(duration: 0.45).delay(delay)) {
                    shown = true
                }
            }
    }
}

public extension View {
    /// 落地页区块入场动画。传入 `delay` 控制错峰时序。
    func landingAppear(delay: Double = 0) -> some View {
        modifier(LandingAppear(delay: delay))
    }
}
