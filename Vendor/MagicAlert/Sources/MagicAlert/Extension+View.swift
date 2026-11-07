import SwiftUI

/// View扩展 - 提供Magic Toast系统的便捷接入方法
public extension View {
    /// 为 View 添加 Toast 功能
    /// 
    /// 使用这个方法可以为任何 SwiftUI View 添加 Toast 显示能力
    /// 只需要在 View 后面调用 `.withMagicToast()` 即可
    ///
    /// ```swift
    /// ContentView()
    ///     .withMagicToast()
    /// ```
    func withMagicToast() -> some View {
        MagicRootView {
            self
        }
    }
    
    /// 为 View 添加 Toast 功能，并在 View 出现时执行设置
    /// 
    /// - Parameter onSetup: 当 View 出现时调用的闭包，可以用来配置 MessageProvider
    ///
    /// ```swift
    /// ContentView()
    ///     .withMagicToast { provider in
    ///         // 配置 provider
    ///     }
    /// ```
    func withMagicToast(onSetup: @escaping (MagicMessageProvider) -> Void = { _ in }) -> some View {
        MagicRootView {
            self
                .onAppear {
                    onSetup(MagicMessageProvider.shared)
                }
        }
    }
}

/// Magic根视图 - 整合了Toast系统的内部容器
/// 用户无需直接使用此视图，应通过 View.withMagicToast() 扩展方法来使用
struct MagicRootView<Content: View>: View {
    private let content: Content
    private let toastManager = MagicToastManager.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .overlay(
                ToastContainer(toastManager: toastManager)
                    .allowsHitTesting(true)
            )
            .environmentObject(toastManager)
    }
}

// MARK: - Position Extension

extension View {
    @ViewBuilder
    func positioned(for displayMode: DisplayMode, in geometry: GeometryProxy) -> some View {
        switch displayMode {
        case .overlay:
            self
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

        case .banner:
            VStack {
                self
                Spacer()
            }

        case .bottom:
            VStack {
                Spacer()
                self
            }
            .padding(.bottom, 40)

        case .corner:
            VStack {
                HStack {
                    Spacer()
                    self
                }
                Spacer()
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
    }

    /// 应用统一的Toast样式，包括背景、阴影和显示动画
    func applyToastStyling() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.red.opacity(0.03))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.red.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#if DEBUG
#Preview {
    MagicToastExampleView()
        .withMagicToast()
        .frame(width: 400, height: 600)
}
#endif
