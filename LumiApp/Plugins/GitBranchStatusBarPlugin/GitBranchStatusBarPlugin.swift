import MagicKit
import SwiftUI
import Foundation

/// Git 分支状态栏插件：在 Agent 模式底部状态栏显示当前项目所属的 Git 分支
actor GitBranchStatusBarPlugin: SuperPlugin {
    nonisolated static let emoji = "🌿"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "GitBranchStatusBar"
    static let displayName: String = "Git Branch Status"
    static let description: String = "Display current git branch in status bar"
    static let iconName: String = "arrow.triangle.branch"
    static let isConfigurable: Bool = false
    static var order: Int { 94 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = GitBranchStatusBarPlugin()

    // MARK: - UI Contributions

    @MainActor func addStatusBarView() -> AnyView? {
        return AnyView(GitBranchStatusBarView())
    }
}

// MARK: - Status Bar View

/// Git 分支状态栏视图
///
/// 监听以下时机自动刷新分支信息：
/// - 视图首次出现（`onAppear`）
/// - 项目路径变化（`onChange(of: currentProjectPath)`）
/// - 从其他应用切回（`applicationDidBecomeActive`）
struct GitBranchStatusBarView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @State private var branch: String?

    var body: some View {
        Group {
            if let branch {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)

                    Text(branch)
                        .font(.system(size: 11))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .onAppear {
            refreshBranch()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            refreshBranch()
        }
        .onApplicationDidBecomeActive {
            refreshBranch()
        }
    }

    private func refreshBranch() {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            branch = nil
            return
        }

        Task.detached { [path] in
            let result = GitBranchHelper.currentBranch(at: path)
            await MainActor.run { [result] in
                self.branch = result
            }
        }
    }
}

// MARK: - Git Branch Helper

/// Git 分支查询辅助工具
enum GitBranchHelper {
    /// 获取指定路径的当前 Git 分支名
    /// - Parameter path: 项目根目录路径
    /// - Returns: 分支名，如果不是 Git 仓库则返回 nil
    static func currentBranch(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", path, "rev-parse", "--abbrev-ref", "HEAD"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (output?.isEmpty == true) ? nil : output
        } catch {
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    GitBranchStatusBarView()
        .frame(height: 30)
        .inRootView()
}
