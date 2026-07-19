import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 主窗口视图
///
/// 使用 LumiFactory 初始化应用，显示内核状态。
public struct WindowMain: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.window-main")
    nonisolated public static let emoji = "🪟"
    nonisolated static let verbose = false

    @State private var kernel: LumiKernel?
    @State private var initializationError: Error?
    @State private var isInitializing = true

    public init() {}

    public var body: some View {
        Group {
            if isInitializing {
                ProgressView("正在初始化...")
                    .frame(width: 400, height: 300)
            } else if let error = initializationError {
                ErrorView(error: error)
            } else if let kernel = kernel {
                KernelStatusView(kernel: kernel)
            }
        }
        .task {
            await initializeKernel()
        }
    }

    private func initializeKernel() async {
        if Self.verbose {
            Self.logger.info("\(Self.t)开始初始化")
        }

        do {
            // 使用 LumiFactory 创建主内核
            let newKernel = try await LumiFactory.createMainKernel()
            self.kernel = newKernel
            if Self.verbose {
                Self.logger.info("\(Self.t)初始化完成")
            }
        } catch {
            Self.logger.error("\(Self.t)初始化失败: \(error.localizedDescription)")
            self.initializationError = error
        }
        self.isInitializing = false
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("启动失败")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(width: 400, height: 300)
    }
}

// MARK: - Kernel Status View

struct KernelStatusView: View {
    let kernel: LumiKernel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("LumiKernel 运行中")
                .font(.title2)
                .fontWeight(.semibold)

            // 服务状态
            VStack(alignment: .leading, spacing: 8) {
                Text("服务状态")
                    .font(.caption)
                    .foregroundColor(.secondary)

                StatusRow(name: "Storage", isAvailable: kernel.storage != nil)
                StatusRow(name: "Project", isAvailable: kernel.project != nil)
                StatusRow(name: "Layout", isAvailable: kernel.layout != nil)
                StatusRow(name: "Chat", isAvailable: kernel.chat != nil)
                StatusRow(name: "Editor", isAvailable: kernel.editor != nil)
                StatusRow(name: "AgentTool", isAvailable: kernel.agentTool != nil)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // 插件列表
            if !kernel.allPlugins.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已注册插件")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(kernel.allPlugins, id: \.id) { plugin in
                        HStack {
                            Image(systemName: "puzzlepiece.fill")
                                .foregroundColor(.blue)
                            Text(plugin.name)
                            Spacer()
                            Text(plugin.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Text("缺少的服务需要通过插件注册")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 450, height: 500)
    }
}

struct StatusRow: View {
    let name: String
    let isAvailable: Bool

    var body: some View {
        HStack {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isAvailable ? .green : .orange)
            Text(name)
            Spacer()
            Text(isAvailable ? "已注册" : "未注册")
                .foregroundColor(.secondary)
        }
    }
}