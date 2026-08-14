import EditorService
import KernelLumi
import SuperLogKit
import SwiftUI
import os

/// 主窗口视图
///
/// 使用 `FactoryCore` 初始化应用。
/// 启动成功后显示成功视图，失败时显示错误视图。
public struct WindowMain: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.window-main")
    nonisolated public static let emoji = "🪟"
    nonisolated static let verbose = false

    @State private var kernel: KernelLumi?
    @State private var initializationError: Error?
    @State private var isInitializing = true
    @State private var windowSaveDelegate: EditorWindowSaveDelegate?
    @State private var mainWindow: NSWindow?
    private let configuration: FactoryConfiguration

    /// 主窗口始终处于活动场景中，可作为应用菜单"Settings..."命令的开窗落点。
    @Environment(\.openWindow) private var openWindow
    private let loadingView: AnyView

    public init(configuration: FactoryConfiguration) {
        self.configuration = configuration
        self.loadingView = AnyView(LoadingView())
    }

    init(configuration: FactoryConfiguration, loadingView: AnyView) {
        self.configuration = configuration
        self.loadingView = loadingView
    }

    public var body: some View {
        Group {
            if isInitializing {
                loadingView
            } else if let error = initializationError {
                CrashedView(error: error)
            } else if let kernel = kernel {
                applyRootOverlays(
                    AppLayoutView(
                        kernel: kernel,
                        showsStatusBar: configuration.showsStatusBar,
                        showsActivityBar: configuration.showsActivityBar
                    ),
                    kernel: kernel
                )
                .overlay(alignment: .top) {
                    WebRequestToastOverlay()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            await initializeKernel()
        }
        // 应用菜单中的"Settings..."命令（SettingsPlugin）以通知方式请求开窗；
        // 主窗口根视图持有 `openWindow` 环境值，在此桥接为打开设置窗口。
        .onReceive(NotificationCenter.default.publisher(for: .lumiOpenSettings)) { _ in
            openWindow(id: AppBootstrap.settingsWindowID)
        }
        .background {
            WindowAccessor { window in
                // WindowAccessor can resolve its NSWindow while SwiftUI is
                // evaluating the current view update. Defer all @State writes
                // until that update has finished.
                Task { @MainActor in
                    guard self.mainWindow !== window else { return }
                    self.mainWindow = window
                    window.configureForLumiMainChrome()
                    self.attachWindowSaveDelegate(to: window)
                }
            }
        }
    }

    private func initializeKernel() async {
        let startTime = DispatchTime.now()
        if Self.verbose {
            Self.logger.info("\(Self.t)开始初始化")
        }

        do {
            // 使用 FactoryCore 创建主内核（包含自检）
            let newKernel = try await FactoryCore.createMainKernel(configuration: configuration)

            if let initialContainerID = configuration.initialContainerID {
                guard newKernel.workspace?.viewContainer(id: initialContainerID) != nil else {
                    throw FactoryConfigurationError.unknownInitialContainerID(initialContainerID)
                }
                newKernel.workspace?.activateContainer(id: initialContainerID)
            }
            self.kernel = newKernel
            if let mainWindow {
                attachWindowSaveDelegate(to: mainWindow)
            }

            // 把 LumiCore 注入到 OpenProjectHandler(单例),让外部
            // `application(_:openFile:)` 路径也能切换项目。
            OpenProjectHandler.shared.configure(kernel: newKernel)

            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
            if Self.verbose {
                Self.logger.info("\(Self.t)初始化完成，耗时 \(elapsed.formattedMilliseconds)")
            }
        } catch {
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
            Self.logger.error("\(Self.t)初始化失败，耗时 \(elapsed.formattedMilliseconds)，错误：\(error.localizedDescription)")
            self.initializationError = error
        }
        self.isInitializing = false
    }

    // MARK: - Root Overlays

    /// 按 order 依次把 rootOverlays 包裹到内容视图外层
    @ViewBuilder
    private func applyRootOverlays<V: View>(_ content: V, kernel: KernelLumi) -> some View {
        let overlays = kernel.workspace?.allRootOverlays ?? []
        let onboardingPages = (kernel.onboarding?.allOnboardingPages ?? [])
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return false
            }
            .map { page in
                OnboardingPageView(order: page.order, view: page.makeView())
            }
        let contentWithEnvironment = content
            .environment(\.onboardingPages, onboardingPages)

        if overlays.isEmpty {
            contentWithEnvironment
        } else {
            overlays.reduce(AnyView(contentWithEnvironment)) { acc, item in
                item.apply(to: acc)
            }
        }
    }

    // MARK: - Window Save Delegate

    /// 为主窗口挂载保存代理，处理关窗/失焦时的自动保存。
    private func attachWindowSaveDelegate(to window: NSWindow) {
        // 从内核解析 EditorService 强类型
        guard let editorService = kernel?.resolveService(EditorService.self) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)EditorService 未就绪，跳过 WindowSaveDelegate 挂载")
            }
            return
        }
        // 避免重复挂载
        if windowSaveDelegate == nil {
            windowSaveDelegate = EditorWindowSaveDelegate(editorService: editorService)
        }
        windowSaveDelegate?.attach(to: window)
    }
}

// MARK: - Time Formatting

private extension Double {
    /// 将毫秒数格式化为可读字符串
    var formattedMilliseconds: String {
        if self < 1 {
            return String(format: "%.2fms", self)
        } else if self < 1000 {
            return String(format: "%.1fms", self)
        } else {
            return String(format: "%.2fs", self / 1000)
        }
    }
}
