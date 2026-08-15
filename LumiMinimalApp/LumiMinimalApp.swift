import AppKit
import FactoryLumi2
import KernelCore
import ProviderLogo
import ProviderMenuBar
import PluginToolbarSettings
import SwiftUI

/// 最小 App：验证「Factory 组装完整主视图 → App 展示窗口」链路。
///
/// App 只需要视图，视图组装（内核装配 + 工具栏/ActivityBar/Rail/内容注入）
/// 全部由 `KernelFactory.makeMainView()` 完成；设置窗口由
/// `KernelFactory.makeSettingsView()` 提供；工具栏设置按钮通过通知
/// （`lumiOpenSettings`）请求打开设置窗口；菜单栏由 `MenuBarProviding` 贡献。
@main
struct LumiMinimalApp: App {
    /// 共享内核：主窗口、设置、菜单栏共用同一实例。
    @StateObject private var kernel: KernelCoreContainer

    @Environment(\.openWindow) private var openWindow

    init() {
        // 装配默认 Provider 不应失败；失败即配置错误。
        let kernel = (try? KernelFactory.makeKernel()) ?? KernelCoreContainer()
        _kernel = StateObject(wrappedValue: kernel)
    }

    var body: some Scene {
        WindowGroup("LumiMinimal", id: "lumi-minimal.main") {
            // App 只做一件事：让 Factory 给一个视图。
            // 注意：`.onReceive` 需应用到整个 `??` 表达式（否则会误绑到 fallback 分支）。
            ((try? KernelFactory.makeMainView()) ?? AnyView(Text("Failed to assemble main view")))
                // 与旧版 Lumi（WindowMain.configureForLumiMainChrome）一致：
                // 窗口内容延伸到标题栏区域（fullSizeContentView），
                // 工具栏从窗口顶部开始渲染，红绿灯悬浮在工具栏上。
                .background {
                    WindowAccessor { window in
                        window.configureForLumiMinimalChrome()
                    }
                }
                // 工具栏「设置」按钮点击后，通知 → 打开设置窗口
                .onReceive(NotificationCenter.default.publisher(for: .lumiOpenSettings)) { _ in
                    openWindow(id: "lumi-minimal.settings")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 480, height: 320)

        Window("设置", id: "lumi-minimal.settings") {
            (try? KernelFactory.makeSettingsView()) ?? AnyView(Text("Failed to assemble settings view"))
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 360, height: 260)

        // 菜单栏：由 MenuBarProviding 贡献的内容与弹窗；
        // 图标优先展示最高优先级插件贡献的 Logo（statusBar 场景），无贡献时回退到默认 SF Symbol。
        MenuBarExtra {
            if let menuBar = kernel.resolveProvider((any MenuBarProviding).self) {
                menuBar.makePopupView()
            } else {
                Text("MenuBarProviding not registered")
            }
        } label: {
            LogoMenuBarLabel(kernel: kernel)
        }
    }
}

/// 菜单栏图标：优先展示最高优先级插件贡献的 Logo，回退到默认 SF Symbol。
///
/// 观察共享内核：LogoProvider 注册时默认转发 `objectWillChange`，
/// 因此 Logo 项增删或高亮状态变化时图标会自动刷新。
private struct LogoMenuBarLabel: View {
    @ObservedObject var kernel: KernelCoreContainer

    var body: some View {
        Group {
            if let logo = kernel.resolveProvider((any LogoProviding).self),
               let item = logo.highestPriorityLogoItem {
                item.makeView(.statusBar)
            } else {
                Image(systemName: "gauge.with.dots.needle.50percent")
            }
        }
        .frame(width: 22, height: 22)
    }
}

/// 配置窗口 chrome：与旧版 Lumi（`WindowMain.configureForLumiMainChrome`）一致，
/// 内容延伸到标题栏区域（fullSizeContentView），红绿灯悬浮在工具栏上，
/// 保证顶部工具栏从窗口最顶部开始渲染、尺寸与旧版完全一致。
private extension NSWindow {
    func configureForLumiMinimalChrome() {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        toolbar = nil
        styleMask.insert(.fullSizeContentView)
    }
}

/// 解析宿主 NSWindow 并应用 chrome 配置的辅助视图。
private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HostView(onResolve: onResolve)
        view.resolveWindowIfAttached()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? HostView)?.resolveWindowIfAttached()
    }

    private final class HostView: NSView {
        let onResolve: (NSWindow) -> Void

        init(onResolve: @escaping (NSWindow) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindowIfAttached()
        }

        func resolveWindowIfAttached() {
            guard let window else { return }
            onResolve(window)
        }
    }
}
