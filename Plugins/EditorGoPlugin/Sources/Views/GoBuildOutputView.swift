import SwiftUI
import LumiCoreKit
import LumiUI
import EditorGoCore

/// Go 构建输出面板视图
///
/// 显示 go build 的实时输出和解析后的构建问题列表。
public struct GoBuildOutputView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @ObservedObject var buildManager: GoBuildManager
    public let projectRoot: String?

    public var body: some View {
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
                                        themeVM.activeChromeTheme.workspaceSecondaryTextColor()
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
                    themeVM.activeChromeTheme.workspaceSecondaryTextColor()
                )

            if buildManager.state.isRunning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(runningTitle)
                    .font(.system(size: 11, weight: .medium))
            } else if buildManager.state == .cancelled {
                HStack(spacing: 4) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 10))
                    Text(LumiPluginLocalization.string("Cancelled", bundle: .module))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
            } else if buildManager.errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "FF453A"))
                    Text("\(buildManager.errorCount) \(LumiPluginLocalization.string("errors", bundle: .module))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "FF453A"))
                }
            } else if buildManager.warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "FF9F0A"))
                    Text("\(buildManager.warningCount) \(LumiPluginLocalization.string("warnings", bundle: .module))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "FF9F0A"))
                }
            } else if buildManager.state == .success {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "30D158"))
                    Text(LumiPluginLocalization.string("Build succeeded", bundle: .module))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "30D158"))
                }
            }

            Spacer()

            if buildManager.state.isRunning {
                Button {
                    buildManager.cancel()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                .help(LumiPluginLocalization.string("Stop", bundle: .module))
            }

            if buildManager.lastBuildDuration > 0 {
                Text(String(format: "%.1fs", buildManager.lastBuildDuration))
                    .font(.system(size: 10))
                    .foregroundColor(
                        themeVM.activeChromeTheme.workspaceTertiaryTextColor()
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.05)
        )
    }

    private var runningTitle: String {
        switch buildManager.state {
        case .building:
            LumiPluginLocalization.string("Building...", bundle: .module)
        case .formatting:
            LumiPluginLocalization.string("Formatting...", bundle: .module)
        case .tidying:
            LumiPluginLocalization.string("Tidying module...", bundle: .module)
        default:
            LumiPluginLocalization.string("Running...", bundle: .module)
        }
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
                            ? Color(hex: "FF453A")
                            : Color(hex: "FF9F0A")
                    )
                    .frame(width: 14)

                Text("\(issue.file):\(issue.line):\(issue.column)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(
                        themeVM.activeChromeTheme.workspaceTextColor()
                    )

                Text(issue.message)
                    .font(.system(size: 11))
                    .foregroundColor(
                        themeVM.activeChromeTheme.workspaceSecondaryTextColor()
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
                    themeVM.activeChromeTheme.workspaceTertiaryTextColor()
                )
            Text(LumiPluginLocalization.string("Run go build to see output", bundle: .module))
                .font(.system(size: 11))
                .foregroundColor(
                    themeVM.activeChromeTheme.workspaceSecondaryTextColor()
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func openFile(at file: String, line: Int) {
        let url = GoIssueFileResolver.url(for: file, projectRoot: projectRoot)
        Task { @MainActor in
            await GoEditorBridge.openFileHandler?(url, projectRoot)
        }
    }
}

enum GoIssueFileResolver {
    static func url(for file: String, projectRoot: String?) -> URL {
        let trimmed = file.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }
        if trimmed.lowercased().hasPrefix("file://") {
            let rawPath = String(trimmed.dropFirst("file://".count))
            let path = rawPath
                .replacingOccurrences(of: "^localhost", with: "", options: .regularExpression)
                .removingPercentEncoding ?? rawPath
            return URL(fileURLWithPath: path)
        }
        if trimmed == "~" || trimmed.hasPrefix("~/") {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }
        if let root = projectRoot {
            return URL(fileURLWithPath: root).appendingPathComponent(trimmed)
        }
        return URL(fileURLWithPath: trimmed)
    }
}
