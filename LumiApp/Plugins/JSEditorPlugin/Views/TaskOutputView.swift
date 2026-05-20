import SwiftUI

struct TaskOutputView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @ObservedObject var taskManager: JSTaskManager
    let projectRoot: String?

    var body: some View {
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
                                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
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
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            if taskManager.state == .running || taskManager.state == .building || taskManager.state == .linting || taskManager.state == .formatting {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
            } else if taskManager.errorCount > 0 {
                Label("\(taskManager.errorCount) \(String(localized: "errors", table: "JSEditor"))", systemImage: "xmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "FF453A"))
            } else if taskManager.warningCount > 0 {
                Label("\(taskManager.warningCount) \(String(localized: "warnings", table: "JSEditor"))", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "FF9F0A"))
            } else if taskManager.state == .success {
                Label(String(localized: "Task succeeded", table: "JSEditor"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "30D158"))
            } else if taskManager.state == .failed {
                Label(String(localized: "Task failed", table: "JSEditor"), systemImage: "xmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "FF453A"))
            }

            Spacer()

            if taskManager.lastDuration > 0 {
                Text(String(format: "%.1fs", taskManager.lastDuration))
                    .font(.system(size: 10))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
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
                    .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

                Text(issue.message)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
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
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text(String(localized: "Run a JS task to see output", table: "JSEditor"))
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
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
        case .building: return String(localized: "Building...", table: "JSEditor")
        case .linting: return String(localized: "Linting...", table: "JSEditor")
        case .formatting: return String(localized: "Formatting...", table: "JSEditor")
        default: return String(localized: "Running...", table: "JSEditor")
        }
    }

    private func openFile(at file: String, line: Int) {
        let url: URL
        if file.hasPrefix("/") {
            url = URL(fileURLWithPath: file)
        } else if let projectRoot {
            url = URL(fileURLWithPath: projectRoot).appendingPathComponent(file)
        } else {
            url = URL(fileURLWithPath: file)
        }
        Task { @MainActor in
            await RootContainer.shared.editorVM.service.refreshProjectContext(for: projectRoot)
            RootContainer.shared.editorVM.service.open(at: url)
        }
        _ = line
    }
}
