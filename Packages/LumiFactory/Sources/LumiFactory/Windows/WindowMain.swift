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

    public init() {}

    public var body: some View {
        Group {
            if isInitializing {
                LoadingView()
            } else if let error = initializationError {
                ErrorView(error: error)
            } else if let kernel = kernel {
                AppLayoutView(kernel: kernel)
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
            // 使用 LumiFactory 创建主内核（包含自检）
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

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在初始化...")
                .font(.headline)
        }
        .frame(width: 400, height: 300)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: Error

    @State private var isCopied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("启动失败")
                    .font(.title)
                    .fontWeight(.semibold)

                GroupBox {
                    VStack(spacing: 12) {
                        Text(String(describing: type(of: error)))
                            .font(.headline)

                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)

                        Button {
                            copyErrorToClipboard()
                        } label: {
                            HStack {
                                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                Text(isCopied ? "已复制" : "复制错误信息")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
                .padding(.horizontal)

                #if os(macOS)
                Button("退出应用") {
                    NSApplication.shared.terminate(nil)
                }
                .controlSize(.large)
                #endif

                Spacer()
            }
        }
        .frame(width: 500, height: 400)
    }

    private func copyErrorToClipboard() {
        let text = "Error: \(type(of: error))\n\(error.localizedDescription)"
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        withAnimation { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isCopied = false }
        }
    }
}