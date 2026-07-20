import EditorService
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 主窗口视图
///
/// 使用 LumiFactory 初始化应用。
/// 启动成功后显示成功视图，失败时显示错误视图。
public struct WindowMain: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.window-main")
    nonisolated public static let emoji = "🪟"
    nonisolated static let verbose = false

    @State private var kernel: LumiKernel?
    @State private var initializationError: Error?
    @State private var isInitializing = true
    @State private var windowSaveDelegate: EditorWindowSaveDelegate?

    public init() {}

    public var body: some View {
        Group {
            if isInitializing {
                LoadingView()
            } else if let error = initializationError {
                CrashedView(error: error)
            } else if let kernel = kernel {
                AppLayoutView(kernel: kernel)
            }
        }
        .task {
            await initializeKernel()
        }
        .background {
            WindowAccessor { window in
                window.configureForLumiMainChrome()
                attachWindowSaveDelegate(to: window)
            }
        }
    }

    private func initializeKernel() async {
        let startTime = DispatchTime.now()
        if Self.verbose {
            Self.logger.info("\(Self.t)开始初始化")
        }

        do {
            // 使用 LumiFactory 创建主内核（包含自检）
            let newKernel = try await LumiFactory.createMainKernel()
            self.kernel = newKernel

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
