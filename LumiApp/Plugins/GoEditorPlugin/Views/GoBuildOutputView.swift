import SwiftUI
import MagicKit

/// Go 构建输出面板视图
///
/// 显示 go build 的实时输出和解析后的构建问题列表。
struct GoBuildOutputView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var buildManager: GoBuildManager
    let projectRoot: String?

    var body: some View {
        VStack(spacing: 0) {
            // 状态栏
            statusBar

            Divider()

            // 内容区
            if buildManager.issues.isEmpty && buildManager.outputLines.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 构建问题
                        ForEach(buildManager.issues) { issue in
                            issueRow(issue)
                        }

                        // 原始输出（如果有非 issue 的输出行）
                        if !buildManager.outputLines.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            ForEach(buildManager.outputLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(
                                        themeManager.activeAppTheme.workspaceSecondaryTextColor()
                                    )
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(
                    themeManager.activeAppTheme.workspaceSecondaryTextColor()
                )

            if buildManager.state == .building {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(String(localized: "Building...", table: "GoEditor"))
                    .font(.system(size: 11, weight: .medium))
            } else if buildManager.errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.error)
                    Text("\(buildManager.errorCount) \(String(localized: "errors", table: "GoEditor"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.error)
                }
            } else if buildManager.warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.warning)
                    Text("\(buildManager.warningCount) \(String(localized: "warnings", table: "GoEditor"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.warning)
                }
            } else if buildManager.state == .success {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.success)
                    Text(String(localized: "Build succeeded", table: "GoEditor"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.success)
                }
            }

            Spacer()

            if buildManager.lastBuildDuration > 0 {
                Text(String(format: "%.1fs", buildManager.lastBuildDuration))
                    .font(.system(size: 10))
                    .foregroundColor(
                        themeManager.activeAppTheme.workspaceTertiaryTextColor()
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            themeManager.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05)
        )
    }

    // MARK: - 构建问题行

    private func issueRow(_ issue: GoBuildIssue) -> some View {
        Button {
            openFile(at: issue.file, line: issue.line)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: issue.severity == .error ? "xmark.circle" : "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundColor(
                        issue.severity == .error
                            ? AppUI.Color.semantic.error
                            : AppUI.Color.semantic.warning
                    )
                    .frame(width: 14)

                Text("\(issue.file):\(issue.line):\(issue.column)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(
                        themeManager.activeAppTheme.workspaceTextColor()
                    )

                Text(issue.message)
                    .font(.system(size: 11))
                    .foregroundColor(
                        themeManager.activeAppTheme.workspaceSecondaryTextColor()
                    )
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hammer")
                .font(.system(size: 20, weight: .thin))
                .foregroundColor(
                    themeManager.activeAppTheme.workspaceTertiaryTextColor()
                )
            Text(String(localized: "Run go build to see output", table: "GoEditor"))
                .font(.system(size: 11))
                .foregroundColor(
                    themeManager.activeAppTheme.workspaceSecondaryTextColor()
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func openFile(at file: String, line: Int) {
        let url: URL
        if file.hasPrefix("/") {
            url = URL(fileURLWithPath: file)
        } else if let root = projectRoot {
            url = URL(fileURLWithPath: root).appendingPathComponent(file)
        } else {
            url = URL(fileURLWithPath: file)
        }
        RootViewContainer.shared.editorVM.service.openFile(at: url)
    }
}
