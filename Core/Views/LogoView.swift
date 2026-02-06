import AppKit
import MagicKit
import OSLog
import SwiftUI

// MARK: - Smart Light Logo (原 Logo1)

/// 方案一：智能光源主题
/// 概念：灯泡 + AI/科技感，象征"点亮灵感、照亮问题"
struct SmartLightLogo: View {
    /// 是否使用单色模式（适用于状态栏等需要黑白显示的场景）
    var isMonochrome: Bool = false
    /// 是否禁用呼吸动画（适用于静态图标）
    var disableAnimation: Bool = false

    @State private var isBreathing = false

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let bulbSize = size * 0.8

            ZStack {
                // 外层光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                isMonochrome ? Color.white.opacity(0.99) : Color.orange.opacity(0.6),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: bulbSize * 0.3,
                            endRadius: size * 0.5
                        )
                    )
                    .scaleEffect(isBreathing ? 1.1 : 1.0)
                    .opacity(isBreathing ? 1.0 : 0.7)

                // 灯泡主体
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: isMonochrome ? [Color.white, Color.white.opacity(0.9)] : [.yellow, .orange]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: bulbSize, height: bulbSize)

                        // 内部灯丝 (闪电形状)
                        Image(systemName: "bolt.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(isMonochrome ? .black : .white)
                            .frame(width: bulbSize * 0.4)
                            .shadow(color: isMonochrome ? .clear : .white, radius: 5)
                    }
                }
            }
            .frame(width: size, height: size)
            .onAppear {
                if !disableAnimation {
                    withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
            }
        }
    }
}

// MARK: - Logo View

struct LogoView: View {
    public enum Variant {
        case appIcon // For Dock, App Icon preview, Large displays
        case statusBar // For Menu Bar (Status Bar) - small, high contrast
        case about // For About window
        case general // Default general purpose
    }

    var variant: Variant = .general
    var isActive: Bool = false // For statusBar variant only

    var body: some View {
        // 状态栏激活时使用彩色，非激活或其他场景根据 variant 决定
        let useMonochrome = variant == .statusBar && !isActive
        return SmartLightLogo(
            isMonochrome: useMonochrome,
            disableAnimation: variant == .statusBar
        )
        .modifier(LogoVariantModifier(variant: variant))
    }
}

// MARK: - Logo Variant Modifier

struct LogoVariantModifier: ViewModifier {
    let variant: LogoView.Variant

    func body(content: Content) -> some View {
        switch variant {
        case .appIcon:
            content
                .padding()
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .background(.black)
        case .statusBar:
            content
                .scaleEffect(0.9)
        case .about:
            content
                .shadow(radius: 5)
        case .general:
            content
        }
    }
}

// MARK: - Status Bar Icon View

/// 状态栏图标视图
/// 显示 Logo 图标和插件提供的内容视图
struct StatusBarIconView: View {
    @ObservedObject var viewModel: StatusBarIconViewModel

    var body: some View {
        HStack(spacing: 4) {
            // Logo 图标
            LogoView(
                variant: .statusBar,
                isActive: viewModel.isActive
            )
            .infinite()
            .frame(width: 16, height: 16)

            // 插件提供的内容视图
            ForEach(viewModel.contentViews.indices, id: \.self) { index in
                viewModel.contentViews[index]
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Interactive Hosting View

/// 能够穿透点击事件的 NSHostingView
/// 用于状态栏图标，让点击事件穿透到下层的 NSStatusBarButton
class InteractiveHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 返回 nil 让点击事件穿透到下层的 NSStatusBarButton
        return nil
    }
}

// MARK: - Previews

#Preview("SmartLightLogo - All Modes") {
    VStack(spacing: 30) {
        // 彩色模式
        SmartLightLogo()
            .frame(width: 200, height: 200)
            .padding()
            .background(Color.black.opacity(0.8))

        // 单色模式（状态栏适用）
        HStack(spacing: 20) {
            SmartLightLogo(isMonochrome: true, disableAnimation: true)
                .frame(width: 40, height: 40)
                .background(Color.black)

            SmartLightLogo(isMonochrome: true, disableAnimation: true)
                .frame(width: 40, height: 40)
                .background(Color.white)
        }
        .padding()
    }
}

#Preview("LogoView - All Variants") {
    ScrollView {
        VStack(spacing: 40) {
            // General & App Icon
            HStack(spacing: 30) {
                VStack {
                    LogoView(variant: .general)
                        .frame(width: 120, height: 120)
                    Text("General").font(.caption)
                }

                VStack {
                    LogoView(variant: .appIcon)
                        .frame(width: 120, height: 120)
                    Text("App Icon").font(.caption)
                }

                VStack {
                    LogoView(variant: .about)
                        .frame(width: 120, height: 120)
                    Text("About").font(.caption)
                }
            }

            // Status Bar - Inactive
            HStack(spacing: 30) {
                VStack {
                    LogoView(variant: .statusBar, isActive: false)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                    Text("Status Bar (Inactive)").font(.caption)
                }

                VStack {
                    LogoView(variant: .statusBar, isActive: true)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                    Text("Status Bar (Active)").font(.caption)
                }
            }
        }
        .padding()
    }
    .frame(height: 600)
}

#Preview("LogoView - Snapshot") {
    LogoView(variant: .appIcon)
        .inMagicContainer(.init(width: 1024, height: 1024), scale: 0.5)
}
