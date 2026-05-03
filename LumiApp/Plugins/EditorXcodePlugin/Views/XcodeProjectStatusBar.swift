import SwiftUI

/// Xcode 项目状态栏视图
struct XcodeProjectStatusBar: View {
    
    @StateObject private var viewModel = XcodeProjectStatusBarViewModel()
    
    var body: some View {
        Group {
            if viewModel.isXcodeProject {
                StatusBarHoverContainer(
                    detailView: XcodeProjectStatusDetailView(viewModel: viewModel),
                    popoverWidth: 440,
                    id: "lumi-xcode-project-status"
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)

                        schemeMenu
                        configurationMenu
                        destinationChip

                        buildContextIndicator
                    }
                    .padding(.horizontal, 4)
                    .frame(width: 400, alignment: .leading)
                }
            }
        }
    }
    
    // MARK: - Build Context 状态指示器
    
    private var buildContextIndicator: some View {
        HStack(spacing: 4) {
            if viewModel.isIndexing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(statusText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .help(viewModel.semanticStatusDescription)
    }
    
    @ViewBuilder
    private var schemeMenu: some View {
        if !viewModel.schemes.isEmpty {
            Menu {
                ForEach(viewModel.schemes, id: \.self) { scheme in
                    Button(action: {
                        viewModel.setActiveScheme(scheme)
                    }) {
                        HStack {
                            Text(scheme)
                            if scheme == viewModel.activeScheme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text(viewModel.activeScheme ?? String(localized: "Scheme", table: "EditorXcodePlugin"))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
    
    @ViewBuilder
    private var configurationMenu: some View {
        if !viewModel.configurations.isEmpty {
            Menu {
                ForEach(viewModel.configurations, id: \.self) { configuration in
                    Button(action: {
                        viewModel.setActiveConfiguration(configuration)
                    }) {
                        HStack {
                            Text(configuration)
                            if configuration == viewModel.activeConfiguration {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 8))
                    Text(viewModel.activeConfiguration ?? String(localized: "Config", table: "EditorXcodePlugin"))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(4)
            }
        }
    }

    @ViewBuilder
    private var destinationChip: some View {
        if let destination = viewModel.activeDestination, !destination.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "macwindow")
                    .font(.system(size: 8))
                Text(destination)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08))
            .cornerRadius(4)
            .help(String(localized: "Target platform for current editor semantic context", table: "EditorXcodePlugin"))
        }
    }

    private var statusColor: Color {
        viewModel.semanticStatusColor
    }
    
    private var statusText: String {
        viewModel.semanticStatusText
    }
}

struct XcodeProjectStatusDetailView: View {
    @ObservedObject var viewModel: XcodeProjectStatusBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "Xcode Context", table: "EditorXcodePlugin"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                buildStatusBadge
            }

            detailRow(String(localized: "Scheme", table: "EditorXcodePlugin"), viewModel.activeScheme ?? String(localized: "Not Selected", table: "EditorXcodePlugin"))
            detailRow(String(localized: "Configuration", table: "EditorXcodePlugin"), viewModel.activeConfiguration ?? String(localized: "Not Selected", table: "EditorXcodePlugin"))
            detailRow(String(localized: "Destination", table: "EditorXcodePlugin"), viewModel.activeDestination ?? String(localized: "Undetermined", table: "EditorXcodePlugin"))
            detailRow(String(localized: "Build Context", table: "EditorXcodePlugin"), viewModel.buildContextStatusDescription)

            HStack {
                Spacer()
                Button {
                    viewModel.resyncBuildContext()
                } label: {
                    if viewModel.isResyncingBuildContext {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(String(localized: "Re-resolving...", table: "EditorXcodePlugin"))
                        }
                    } else {
                        Text(String(localized: "Re-resolve Build Context", table: "EditorXcodePlugin"))
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
                .disabled(viewModel.isResyncingBuildContext)
            }

            Divider()

            if let snapshot = viewModel.latestEditorSnapshot {
                detailRow(String(localized: "Workspace", table: "EditorXcodePlugin"), snapshot.workspaceName)
                detailRow(String(localized: "Current File", table: "EditorXcodePlugin"), snapshot.currentFilePath ?? String(localized: "No File Open", table: "EditorXcodePlugin"))
                detailRow(String(localized: "Preferred Target", table: "EditorXcodePlugin"), snapshot.currentFileTarget ?? String(localized: "Undetermined", table: "EditorXcodePlugin"))
                detailRow(
                    String(localized: "Matched Targets", table: "EditorXcodePlugin"),
                    snapshot.currentFileMatchedTargets.isEmpty ? String(localized: "None", table: "EditorXcodePlugin") : snapshot.currentFileMatchedTargets.joined(separator: ", ")
                )
                detailRow(
                    String(localized: "Scheme Targets", table: "EditorXcodePlugin"),
                    snapshot.activeSchemeBuildableTargets.isEmpty ? String(localized: "None", table: "EditorXcodePlugin") : snapshot.activeSchemeBuildableTargets.joined(separator: ", ")
                )
                if !viewModel.semanticReport.reasons.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Semantic Availability", table: "EditorXcodePlugin"))
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(viewModel.semanticReport.reasons) { reason in
                            reasonRow(reason)
                        }
                    }
                }
            } else {
                Text(String(localized: "No editor context snapshot available.", table: "EditorXcodePlugin"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var buildStatusBadge: some View {
        Text(viewModel.buildContextStatusDescription)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
        }
    }

    private func reasonRow(_ reason: XcodeSemanticAvailability.Reason) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color(for: reason.severity))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(reason.title)
                    .font(.system(size: 11, weight: .medium))
                Text(reason.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func color(for severity: XcodeSemanticAvailability.ReasonSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - 文件归属提示视图

/// 文件未绑定到任何 Target 的提示
/// 对应 Phase 8: "当前文件未绑定有效 target" 提示
struct XcodeFileNotInTargetWarning: View {
    let fileName: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "File Not Registered in Project", table: "EditorXcodePlugin"))
                    .font(.headline)
            }
            
            let format = String(localized: "\"%@\" is not bound to any compilation target. Cross-file semantic navigation may be unavailable.", table: "EditorXcodePlugin")
            Text(String(format: format, fileName))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button(String(localized: "Got It", table: "EditorXcodePlugin"), action: onDismiss)
                    .buttonStyle(.bordered)
                
                Button(String(localized: "Open in Xcode", table: "EditorXcodePlugin")) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        XcodeProjectStatusBar()
            .padding()
        
        Divider()
        
        XcodeFileNotInTargetWarning(fileName: "MyFile.swift") { }
            .padding()
    }
}
