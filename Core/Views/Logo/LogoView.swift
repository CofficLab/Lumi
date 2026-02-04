import AppKit
import MagicKit
import OSLog
import SwiftUI

// MARK: - Logo View

struct LogoView: View {
    public enum Variant {
        case appIcon // For Dock, App Icon preview, Large displays
        case statusBar // For Menu Bar (Status Bar) - small, high contrast
        case about // For About window
        case general // Default general purpose
    }

    public enum Design: Int, CaseIterable {
        case smartLight = 1 // Logo1
        case elfAssistant = 2 // Logo2
        case multiFunction = 3 // Logo3
        case letterForm = 4 // Logo4
    }

    var variant: Variant = .general
    var design: Design = .smartLight
    var isActive: Bool = false // For statusBar variant only

    var body: some View {
        GeometryReader { _ in
            Group {
                switch design {
                case .smartLight:
                    // 状态栏激活时使用彩色，非激活或其他场景根据 variant 决定
                    let useMonochrome = variant == .statusBar && !isActive
                    Logo1(
                        isMonochrome: useMonochrome,
                        disableAnimation: variant == .statusBar
                    )
                case .elfAssistant:
                    Logo2()
                case .multiFunction:
                    Logo3()
                case .letterForm:
                    Logo4()
                }
            }
            .modifier(LogoVariantModifier(variant: variant))
        }
    }
}

// MARK: - Logo Variant Modifier

struct LogoVariantModifier: ViewModifier {
    let variant: LogoView.Variant

    func body(content: Content) -> some View {
        switch variant {
        case .appIcon:
            content
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .background(Color.black)
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
                design: .smartLight,
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

#Preview("LogoView - All Variants") {
    ScrollView {
        VStack(spacing: 40) {
            // General & App Icon
            HStack(spacing: 30) {
                VStack {
                    LogoView(variant: .general, design: .smartLight)
                        .frame(width: 120, height: 120)
                    Text("General").font(.caption)
                }

                VStack {
                    LogoView(variant: .appIcon, design: .smartLight)
                        .frame(width: 120, height: 120)
                    Text("App Icon").font(.caption)
                }

                VStack {
                    LogoView(variant: .about, design: .smartLight)
                        .frame(width: 120, height: 120)
                    Text("About").font(.caption)
                }
            }

            // Status Bar - Inactive
            HStack(spacing: 30) {
                VStack {
                    LogoView(variant: .statusBar, design: .smartLight, isActive: false)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                    Text("Status Bar (Inactive)").font(.caption)
                }

                VStack {
                    LogoView(variant: .statusBar, design: .smartLight, isActive: true)
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
    LogoView(variant: .appIcon, design: .smartLight)
        .inMagicContainer(.init(width: 500, height: 500), scale: 1)
}
