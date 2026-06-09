import SwiftUI
import SuperLogKit
import LumiUI
import XcodeKit

/// Xcode 项目状态栏视图
public struct XcodeProjectStatusBar: View, SuperLog {
    public nonisolated static let emoji = "🔨"

    @StateObject private var viewModel = XcodeProjectStatusBarViewModel.shared

    public var body: some View {
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
                }
            }
        }
        .onAppear {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.info("\(self.t)onAppear，isXcodeProject=\(viewModel.isXcodeProject)")
                }
            }
        }
        .onChange(of: viewModel.isXcodeProject) { _, newValue in
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.info("\(self.t)isXcodeProject 变化: \(newValue)")
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
                Text(viewModel.activeScheme ?? String(localized: "Scheme", bundle: .module))
                    .lineLimit(1)
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
                Text(viewModel.activeConfiguration ?? String(localized: "Config", bundle: .module))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var destinationChip: some View {
        if let destination = viewModel.activeDestination, !destination.isEmpty {
            Text(destination)
                .lineLimit(1)
                .help(String(localized: "Target platform for current editor semantic context", bundle: .module))
        }
    }

    private var statusColor: Color {
        viewModel.semanticStatusColor
    }

    private var statusText: String {
        viewModel.semanticStatusText
    }
}

public struct XcodeProjectStatusDetailView: View {
    @ObservedObject var viewModel: XcodeProjectStatusBarViewModel

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "Xcode Context", bundle: .module))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                buildStatusBadge
            }

            detailRow(String(localized: "Scheme", bundle: .module), viewModel.activeScheme ?? String(localized: "Not Selected", bundle: .module))
            detailRow(String(localized: "Configuration", bundle: .module), viewModel.activeConfiguration ?? String(localized: "Not Selected", bundle: .module))
            detailRow(String(localized: "Destination", bundle: .module), viewModel.activeDestination ?? String(localized: "Undetermined", bundle: .module))
            detailRow(String(localized: "Build Context", bundle: .module), viewModel.buildContextStatusDescription)

            HStack {
                Spacer()
                Button {
                    viewModel.resyncBuildContext()
                } label: {
                    if viewModel.isResyncingBuildContext {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(String(localized: "Re-resolving...", bundle: .module))
                        }
                    } else {
                        Text(String(localized: "Re-resolve Build Context", bundle: .module))
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
                .disabled(viewModel.isResyncingBuildContext)
            }

            Divider()

            if let snapshot = viewModel.latestEditorSnapshot {
                detailRow(String(localized: "Workspace", bundle: .module), snapshot.workspaceName)
                detailRow(String(localized: "Current File", bundle: .module), snapshot.currentFilePath ?? String(localized: "No File Open", bundle: .module))
                detailRow(String(localized: "Preferred Target", bundle: .module), snapshot.currentFileTarget ?? String(localized: "Undetermined", bundle: .module))
                detailRow(
                    String(localized: "Matched Targets", bundle: .module),
                    snapshot.currentFileMatchedTargets.isEmpty ? String(localized: "None", bundle: .module) : snapshot.currentFileMatchedTargets.joined(separator: ", ")
                )
                detailRow(
                    String(localized: "Scheme Targets", bundle: .module),
                    snapshot.activeSchemeBuildableTargets.isEmpty ? String(localized: "None", bundle: .module) : snapshot.activeSchemeBuildableTargets.joined(separator: ", ")
                )
                if !viewModel.semanticReport.reasons.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Semantic Availability", bundle: .module))
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(viewModel.semanticReport.reasons) { reason in
                            reasonRow(reason)
                        }
                    }
                }
            } else {
                Text(String(localized: "No editor context snapshot available.", bundle: .module))
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

public struct XcodeFileNotInTargetWarning: View {
    public let fileName: String
    public let onDismiss: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "File Not Registered in Project", bundle: .module))
                    .font(.headline)
            }

            Text(
                String(
                    format: String(localized: "\"%@\" is not bound to any compilation target. Cross-file semantic navigation may be unavailable.", bundle: .module),
                    fileName
                )
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(String(localized: "Got It", bundle: .module), action: onDismiss)
                    .buttonStyle(.bordered)

                Button(String(localized: "Open in Xcode", bundle: .module)) {
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
