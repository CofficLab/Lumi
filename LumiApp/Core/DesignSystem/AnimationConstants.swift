import SwiftUI
import AppKit

// MARK: - 动画系统
///
/// 统一的动画常量和辅助函数，确保整个应用的动画一致性。
///
enum DesignAnimations {
    // MARK: - 时长
    enum Duration {
        /// 微交互（150ms）- 按钮点击、小悬停效果
        static let micro: TimeInterval = 0.15

        /// 标准过渡（200ms）- 大多数 UI 状态变化
        static let standard: TimeInterval = 0.20

        /// 中等动画（300ms）- 复杂过渡、页面切换
        static let moderate: TimeInterval = 0.30

        /// 缓慢动画（500ms）- 大型布局变化
        static let slow: TimeInterval = 0.50
    }

    // MARK: - 动画曲线
    enum Curve {
        /// 平滑退出 - 进入元素的自然过渡
        static let easeOut = SwiftUI.Animation.easeOut(duration: Duration.standard)

        /// 平滑进入 - 退出元素的自然过渡
        static let easeIn = SwiftUI.Animation.easeIn(duration: Duration.standard)

        /// 平滑进出 - 双向过渡
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: Duration.standard)

        /// 弹簧动画 - 物理感的交互反馈
        static func spring(response: Double = 0.3, dampingFraction: Double = 0.7) -> SwiftUI.Animation {
            .spring(response: response, dampingFraction: dampingFraction)
        }

        /// 交互式弹簧 - 支持拖拽的动画
        static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.76) -> SwiftUI.Animation {
            .interactiveSpring(response: response, dampingFraction: dampingFraction)
        }
    }

    // MARK: - 预设动画
    enum Preset {
        /// 快速淡入
        static let fadeIn = SwiftUI.Animation.easeOut(duration: Duration.micro)

        /// 标准淡入
        static let fadeInStandard = SwiftUI.Animation.easeOut(duration: Duration.standard)

        /// 平滑移动
        static let smoothMove = SwiftUI.Animation.easeOut(duration: Duration.standard)

        /// 弹性弹出
        static let bounce = Curve.spring()

        /// 交互响应
        static let responsive = Curve.interactiveSpring()

        /// 页面切换
        static let pageTransition = SwiftUI.Animation.easeInOut(duration: Duration.moderate)
    }

    // MARK: - 延迟
    enum Delay {
        /// 无延迟
        static let none: TimeInterval = 0

        /// 微延迟 - 用于交错效果
        static let micro: TimeInterval = 0.05

        /// 小延迟
        static let short: TimeInterval = 0.1

        /// 中延迟
        static let medium: TimeInterval = 0.15

        /// 大延迟
        static let long: TimeInterval = 0.2
    }
}

// MARK: - 动画辅助
extension DesignAnimations {
    /// 检查是否应减少动画
    static var shouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 获取适配后的动画（尊重减少动画偏好）
    static func accessibleAnimation(_ animation: SwiftUI.Animation) -> SwiftUI.Animation {
        shouldReduceMotion ? .linear(duration: 0.01) : animation
    }

    /// 获取适配后的时长
    static func accessibleDuration(_ duration: TimeInterval) -> TimeInterval {
        shouldReduceMotion ? 0.01 : duration
    }
}

// MARK: - View 扩展
extension View {
    /// 应用动画（自动适配减少动画偏好）
    func animate(_ animation: SwiftUI.Animation) -> some View {
        self.animation(DesignAnimations.accessibleAnimation(animation), value: true)
    }

    /// 悬停响应
    func hoverResponse(
        isHovering: Bool,
        scale: CGFloat = 1.02,
        opacity: Double = 0.8
    ) -> some View {
        self
            .scaleEffect(isHovering ? scale : 1.0)
            .opacity(isHovering ? opacity : 1.0)
            .animation(DesignAnimations.accessibleAnimation(.easeOut(duration: DesignAnimations.Duration.micro)), value: isHovering)
    }

    /// 点击反馈
    func pressResponse(isPressing: Bool, scale: CGFloat = 0.97) -> some View {
        self
            .scaleEffect(isPressing ? scale : 1.0)
            .animation(DesignAnimations.accessibleAnimation(.spring(response: 0.2, dampingFraction: 0.7)), value: isPressing)
    }
}

// MARK: - 视图修饰符
/// 淡入修饰符
struct FadeInModifier: ViewModifier {
    let duration: TimeInterval
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(DesignAnimations.accessibleAnimation(.easeOut(duration: duration))) {
                    opacity = 1
                }
            }
    }
}

/// 滑入修饰符
struct SlideInModifier: ViewModifier {
    let edge: Edge
    let offset: CGFloat
    @State private var position: CGFloat

    init(edge: Edge, offset: CGFloat = 20) {
        self.edge = edge
        self.offset = offset

        switch edge {
        case .leading:
            self._position = State(initialValue: -offset)
        case .trailing:
            self._position = State(initialValue: offset)
        case .top:
            self._position = State(initialValue: -offset)
        case .bottom:
            self._position = State(initialValue: offset)
        }
    }

    func body(content: Content) -> some View {
        content
            .offset(
                x: edge == .leading || edge == .trailing ? position : 0,
                y: edge == .top || edge == .bottom ? position : 0
            )
            .onAppear {
                withAnimation(DesignAnimations.Preset.smoothMove) {
                    position = 0
                }
            }
    }
}

/// 缩放弹出修饰符
struct ScalePopModifier: ViewModifier {
    let initialScale: CGFloat
    @State private var scale: CGFloat

    init(initialScale: CGFloat = 0.9) {
        self.initialScale = initialScale
        self._scale = State(initialValue: initialScale)
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(DesignAnimations.Preset.bounce) {
                    scale = 1.0
                }
            }
    }
}

/// 交错动画修饰符（用于列表项逐个出现）
struct StaggerAnimationModifier: ViewModifier {
    let index: Int
    let baseDelay: TimeInterval

    func body(content: Content) -> some View {
        content
            .modifier(FadeInModifier(duration: DesignAnimations.Duration.moderate))
            .onAppear {
                let delay = baseDelay * Double(index)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // 触发动画
                }
            }
    }
}

// MARK: - 便捷 View 扩展
extension View {
    /// 应用淡入效果
    func fadeIn(duration: TimeInterval = DesignAnimations.Duration.micro) -> some View {
        self.modifier(FadeInModifier(duration: duration))
    }

    /// 应用滑入效果
    func slideIn(edge: Edge = .bottom, offset: CGFloat = 20) -> some View {
        self.modifier(SlideInModifier(edge: edge, offset: offset))
    }

    /// 应用缩放弹出效果
    func scalePop(initialScale: CGFloat = 0.9) -> some View {
        self.modifier(ScalePopModifier(initialScale: initialScale))
    }

    /// 应用交错动画（用于列表）
    func staggered(index: Int, baseDelay: TimeInterval = DesignAnimations.Delay.micro) -> some View {
        self.modifier(StaggerAnimationModifier(index: index, baseDelay: baseDelay))
    }
}

// MARK: - 过渡动画
extension AnyTransition {
    /// 淡入 + 滑动过渡
    static var fadeAndSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// 缩放 + 淡入过渡
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        )
    }

    /// 自定义滑动过渡
    static func slide(edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge),
            removal: .move(edge: edge)
        )
    }
}

// MARK: - 状态动画辅助
/// 视图状态动画包装器
@MainActor
class AnimatingState<T: Equatable>: ObservableObject {
    @Published var value: T {
        didSet {
            animateChange()
        }
    }

    private let animation: SwiftUI.Animation
    private var animationTask: Task<Void, Never>?

    init(initialValue: T, animation: SwiftUI.Animation = .easeOut(duration: 0.2)) {
        self.value = initialValue
        self.animation = animation
    }

    private func animateChange() {
        animationTask?.cancel()
        animationTask = Task {
            try? await Task.sleep(nanoseconds: 0)
            // 动画会自动通过 @Published 触发
        }
    }

    deinit {
        animationTask?.cancel()
    }
}

// MARK: - 预览
#Preview("动画效果") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        // 淡入
        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
            .fill(DesignTokens.Color.gradients.primaryGradient)
            .frame(width: 100, height: 100)
            .fadeIn()

        // 滑入
        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
            .fill(DesignTokens.Material.glass)
            .frame(width: 100, height: 100)
            .overlay(
                Text("滑入")
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            )
            .slideIn(edge: .bottom)

        // 缩放弹出
        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
            .fill(DesignTokens.Color.semantic.success)
            .frame(width: 100, height: 100)
            .overlay(
                Text("弹出")
                    .foregroundColor(.white)
            )
            .scalePop()

        // 悬停响应示例
        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .fill(DesignTokens.Material.glass)
            .frame(width: 120, height: 44)
            .overlay(
                Text("悬停我")
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            )
            .onHover { hovering in
                // 悬停效果需要配合 @State
            }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Color.basePalette.deepBackground)
}

#Preview("交错动画列表") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        ForEach(0..<5) { index in
            GlassRow {
                HStack {
                    Text("项 \(index + 1)")
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    Spacer()
                }
            }
            .staggered(index: index, baseDelay: DesignAnimations.Delay.short)
        }
    }
    .padding(DesignTokens.Spacing.md)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
