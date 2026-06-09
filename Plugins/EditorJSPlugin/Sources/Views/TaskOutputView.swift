import LumiCoreKit
import LumiUI
import SwiftUI

@MainActor
public enum JSEditorBridge {
    public static var openFileHandler: ((URL, String?) async -> Void)?
}

public struct TaskOutputView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @ObservedObject var taskManager: JSTaskManager
    public let projectRoot: String?

    public var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()

            if taskManager.outputLines.isEmpty && taskManager.issues.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(taskManager.issues) { issue in
                            issueRow(issue)
                        }

                        if !taskManager.outputLines.isEmpty {
                            Divider().padding(.vertical, 4)
                            ForEach(Array(taskManager.outputLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
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

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())

            if taskManager.state.isRunning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
            } else if taskManager.state == .cancelled {
                Label(String(localized: "Cancelled", bundle: .module), systemImage: "stop.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
            } else if taskManager.errorCount > 0 {
                Label("\(taskManager.errorCount) \(String(localized: "errors", bundle: .module))", systemImage: "xmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "FF453A"))
            } else if taskManager.warningCount > 0 {
                Label("\(taskManager.warningCount) \(String(localized: "warnings", bundle: .module))", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "FF9F0A"))
            } else if taskManager.state == .success {
                Label(String(localized: "Task succeeded", bundle: .module), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "30D158"))
            } else if taskManager.state == .failed {
                Label(String(localized: "Task failed", bundle: .module), systemImage: "xmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "FF453A"))
            }

            Spacer()

            if taskManager.state.isRunning {
                Button {
                    taskManager.cancel()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                .help(String(localized: "Stop", bundle: .module))
            }

            if taskManager.lastDuration > 0 {
                Text(String(format: "%.1fs", taskManager.lastDuration))
                    .font(.system(size: 10))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceTertiaryTextColor())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    private func issueRow(_ issue: JSBuildIssue) -> some View {
        Button {
            openFile(at: issue.file, line: issue.line)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: issue.severity == .error ? "xmark.circle" : "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundColor(issue.severity == .error ? Color(hex: "FF453A") : Color(hex: "FF9F0A"))
                    .frame(width: 14)

                Text("\(issue.file):\(issue.line):\(issue.column)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceTextColor())

                Text(issue.message)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 20, weight: .thin))
                .foregroundColor(themeVM.activeChromeTheme.workspaceTertiaryTextColor())
            Text(String(localized: "Run a JS task to see output", bundle: .module))
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconName: String {
        switch taskManager.state {
        case .building: return "hammer"
        case .testing: return "testtube.2"
        case .linting: return "checklist"
        case .formatting: return "text.alignleft"
        default: return "terminal"
        }
    }

    private var statusText: String {
        switch taskManager.state {
        case .building: return String(localized: "Building...", bundle: .module)
        case .linting: return String(localized: "Linting...", bundle: .module)
        case .formatting: return String(localized: "Formatting...", bundle: .module)
        default: return String(localized: "Running...", bundle: .module)
        }
    }

    private func openFile(at file: String, line: Int) {
        let url = JSIssueFileResolver.url(for: file, projectRoot: projectRoot)
        Task { @MainActor in
            await JSEditorBridge.openFileHandler?(url, projectRoot)
        }
        _ = line
    }
}

enum JSIssueFileResolver {
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
        if let projectRoot {
            return URL(fileURLWithPath: projectRoot).appendingPathComponent(trimmed)
        }
        return URL(fileURLWithPath: trimmed)
    }
}
