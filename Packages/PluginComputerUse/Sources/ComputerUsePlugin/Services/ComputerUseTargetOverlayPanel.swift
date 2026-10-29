import AppKit
import SwiftUI

/// 目标窗口遮罩的强度。
///
/// 两条执行路径的用户预期不同，因此遮罩的表现也不同：
/// - AX 路径是**后台操作**：目标应用不激活、不抢焦点，用户可能正在做别的事，
///   遮罩必须克制，不能挡住内容；
/// - 原生输入路径是**独占桌面**：Lumi 正在真实地移动鼠标、敲键盘，
///   用户本就应该让路，遮罩可以明确表达「现在这个窗口归 Lumi 管」。
enum ComputerUseTargetOverlayIntensity {
    /// AX 路径：极淡的色调 + 角标，不干扰内容阅读。
    case subtle
    /// 原生输入路径：更明显的色调 + 角标，明确宣告接管。
    case blocking

    /// 遮罩层的不透明度。
    var tintOpacity: Double {
        switch self {
        case .subtle: return 0.06
        case .blocking: return 0.22
        }
    }

    /// 角标底色。
    ///
    /// 使用系统色而非主题色：遮罩是脱离 Lumi 窗口的桌面级浮层，
    /// 它出现在别的应用上方，不应该携带 Lumi 自己的配色语义。
    var badgeColor: Color {
        switch self {
        case .subtle: return .accentColor
        case .blocking: return .orange
        }
    }

    /// 角标主文案。
    ///
    /// 两种强度的语义不同：AX 路径只是操作了一个控件，原生输入路径则
    /// 真正接管了鼠标键盘。文案必须让用户一眼分清这两种情况。
    func badgeText(applicationName: String) -> String {
        switch self {
        case .subtle:
            return computerUseText("Lumi is operating {app}", ["app": applicationName])
        case .blocking:
            return computerUseText("Lumi is controlling {app}", ["app": applicationName])
        }
    }
}

/// 遮罩的可观察状态，供 SwiftUI 视图渲染。
@MainActor
final class ComputerUseTargetOverlayModel: ObservableObject {
    @Published var applicationName: String = ""
    @Published var intensity: ComputerUseTargetOverlayIntensity = .subtle
    /// 淡出阶段为 true，此时角标降低存在感但仍然可见。
    @Published var isFading: Bool = false
}

/// 目标窗口上的提示遮罩。
///
/// 关键属性：
/// - `borderless` + 透明背景——只显示绘制的色调与角标；
/// - `level = .screenSaver`——高于普通应用窗口，目标应用在前台时也盖得住；
/// - `collectionBehavior` 跨 Space、随全屏应用显现；
/// - `ignoresMouseEvents = true`——**必须**。
///
/// - Important: `ignoresMouseEvents` 不能关。原生输入路径通过
///   `CGEvent` 合成点击，如果遮罩吞掉这些事件，Lumi 的点击会打在遮罩上
///   而不是目标应用上，操作会静默失效。遮罩只做**视觉**提示，
///   绝不参与输入分发。
@MainActor
final class ComputerUseTargetOverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        // 遮罩永远不参与焦点：目标应用可能没激活，遮罩也不能把它激活。
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 遮罩层视图：整窗色调 + 标题栏位置的角标。
struct ComputerUseTargetOverlayView: View {
    @ObservedObject var model: ComputerUseTargetOverlayModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.accentColor
                .opacity(model.intensity.tintOpacity)
            badge
                .padding(.top, 6)
                .padding(.leading, 10)
        }
    }

    private var badge: some View {
        HStack(spacing: 6) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 11, weight: .semibold))
            Text(model.intensity.badgeText(applicationName: model.applicationName))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(model.intensity.badgeColor, in: Capsule())
        .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
        .opacity(model.isFading ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.25), value: model.isFading)
    }
}
