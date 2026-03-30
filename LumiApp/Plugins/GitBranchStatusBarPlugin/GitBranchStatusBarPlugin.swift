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

    @MainActor func addStatusBarTrailingView() -> AnyView? {
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
    @State private var gitInfo: GitInfo?

    var body: some View {
        Group {
            if let branch {
                StatusBarHoverContainer(
                    detailView: GitBranchDetailView(gitInfo: gitInfo),
                    id: "git-branch-status"
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)

                        Text(branch)
                            .font(.system(size: 11))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
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
            gitInfo = nil
            return
        }

        Task.detached { [path] in
            let result = GitBranchHelper.currentBranch(at: path)
            let info = await GitBranchHelper.getGitInfo(at: path)
            await MainActor.run {
                self.branch = result
                self.gitInfo = info
            }
        }
    }
}

// MARK: - Git Branch Detail View

/// Git 分支详情视图（在 popover 中显示）
struct GitBranchDetailView: View {
    let gitInfo: GitInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("Git 信息")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            Divider()

            if let info = gitInfo {
                // Git 信息网格
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    GitInfoRow(label: "当前分支", value: info.branch)
                    GitInfoRow(label: "远程仓库", value: info.remote)
                    GitInfoRow(label: "提交信息", value: info.lastCommit)
                    GitInfoRow(label: "提交者", value: info.author)

                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text("状态")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .frame(width: 70, alignment: .leading)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(info.isDirty ? DesignTokens.Color.semantic.warning : DesignTokens.Color.semantic.success)
                                .frame(width: 6, height: 6)

                            Text(info.isDirty ? "有未提交更改" : "工作区干净")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        }

                        Spacer()
                    }
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(DesignTokens.Color.semantic.warning)

                    Text("无法获取 Git 信息")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
    }
}

/// Git 信息行
struct GitInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .lineLimit(2)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - Git Info Model

/// Git 信息模型
struct GitInfo {
    let branch: String
    let remote: String
    let lastCommit: String
    let author: String
    let isDirty: Bool
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

    /// 获取 Git 仓库详细信息
    /// - Parameter path: 项目根目录路径
    /// - Returns: Git 信息
    static func getGitInfo(at path: String) async -> GitInfo? {
        guard let branch = currentBranch(at: path) else {
            return nil
        }

        let remote = await getRemote(at: path)
        let (lastCommit, author) = await getLastCommit(at: path)
        let isDirty = await checkDirty(at: path)

        return GitInfo(
            branch: branch,
            remote: remote,
            lastCommit: lastCommit,
            author: author,
            isDirty: isDirty
        )
    }

    private static func getRemote(at path: String) async -> String {
        await runGitCommand(path, args: ["remote", "-v"])
            .components(separatedBy: "\n")
            .first?
            .components(separatedBy: CharacterSet.whitespaces)
            .first ?? "无"
    }

    private static func getLastCommit(at path: String) async -> (message: String, author: String) {
        let message = await runGitCommand(path, args: ["log", "-1", "--pretty=%s"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let author = await runGitCommand(path, args: ["log", "-1", "--pretty=%an"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (message: message.isEmpty ? "无" : message, author: author.isEmpty ? "无" : author)
    }

    private static func checkDirty(at path: String) async -> Bool {
        let output = await runGitCommand(path, args: ["status", "--porcelain"])
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func runGitCommand(_ path: String, args: [String]) async -> String {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["git", "-C", path] + args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8) ?? ""
            } catch {
                return ""
            }
        }.value
    }
}

// MARK: - Preview

#Preview {
    GitBranchStatusBarView()
        .frame(height: 30)
        .inRootView()
}

#Preview("Detail View") {
    GitBranchDetailView(gitInfo: GitInfo(
        branch: "main",
        remote: "origin",
        lastCommit: "Fix status bar hover effect",
        author: "Developer",
        isDirty: true
    ))
    .frame(width: 300)
}
