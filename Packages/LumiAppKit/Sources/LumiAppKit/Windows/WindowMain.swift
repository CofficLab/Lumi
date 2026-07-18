import LumiChatKit
import LumiCoreKit
import os
import SuperLogKit
import SwiftUI

public struct WindowMain: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.window-main")
    nonisolated public static let emoji = "🪟"
    nonisolated static let verbose = false

    @State private var container: RootContainer?
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
            } else if let container = container {
                RootView(container: container) {
                    AppLayoutView(
                        lumiCore: container.lumiCore,
                        pluginService: container.pluginService,
                        editorCoreService: container.editorCoreService,
                        lumiUIService: container.lumiUIService,
                        chatService: container.chatService,
                        chatSectionCoordinator: container.chatSectionCoordinator
                    )
                }
                .background {
                    WindowAccessor { window in
                        window.configureForLumiMainChrome()
                        attachWindowSaveDelegate(to: window)
                    }
                }
            }
        }
        .task {
            await initializeContainer()
        }
    }

    // MARK: - Initialization

    private func initializeContainer() async {
        let startTime = DispatchTime.now()
        Self.logger.info("\(Self.t)开始初始化主窗口容器")

        do {
            let newContainer = try RootContainer()
            self.container = newContainer

            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
            Self.logger.info("\(Self.t)RootContainer 创建完成，耗时 \(elapsed.formattedMilliseconds)")

            // 等待所有插件 lifecycle 完成，再收集工具贡献。
            // - 保证 agentTools 在插件状态就绪后被调用，避免"插件状态未初始化"误报；
            // - 若有插件工具加载失败，抛聚合错误，由下方 catch 走 CrashedView。
            try await newContainer.bootstrapAfterPluginLifecycle()

            // 把 LumiCore 注入到 OpenProjectHandler(单例),让外部
            // `application(_:openFile:)` 路径也能切换项目。
            OpenProjectHandler.shared.configure(lumiCore: newContainer.lumiCore)
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
        guard let container else { return }
        // 避免重复挂载
        if windowSaveDelegate == nil {
            windowSaveDelegate = EditorWindowSaveDelegate(
                editorService: container.editorCoreService.editorService
            )
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
