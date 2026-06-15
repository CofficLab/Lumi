import SwiftUI
import SuperLogKit
import LumiUI
import XcodeKit
import LumiCoreKit

/// Xcode 项目状态栏视图
public struct XcodeProjectStatusBar: View, SuperLog {
    public nonisolated static let emoji = "🔨"

    @LumiTheme private var theme
    @StateObject private var viewModel = XcodeProjectStatusBarViewModel.shared

    public var body: some View {
        Group {
            if viewModel.isXcodeProject {
                StatusBarHoverContainer(
                    detailView: XcodeProjectStatusDetailView(viewModel: viewModel),
                    popoverWidth: 440,
                    id: "lumi-xcode-project-status",
                    chrome: .titleToolbar
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
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.info("\(self.t)onAppear，isXcodeProject=\(viewModel.isXcodeProject)")
                }
            }
        }
        .onChange(of: viewModel.isXcodeProject) { _, newValue in
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.info("\(self.t)isXcodeProject 变化: \(newValue)")
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
                .foregroundStyle(theme.textSecondary)
        }
        .help(viewModel.semanticStatusDescription)
    }

    static func titleToolbarSecondaryTextColor(theme: any LumiUITheme) -> Color {
        theme.textSecondary
    }

    static func titleToolbarPrimaryTextColor(theme: any LumiUITheme) -> Color {
        theme.textPrimary
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
                Text(viewModel.activeScheme ?? LumiPluginLocalization.string("Scheme", bundle: .module))
                    .lineLimit(1)
            }
        } else if viewModel.isXcodeProject {
            Text(viewModel.activeScheme ?? LumiPluginLocalization.string("Resolving build context...", bundle: .module))
                .lineLimit(1)
                .foregroundStyle(.secondary)
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
                Text(viewModel.activeConfiguration ?? LumiPluginLocalization.string("Config", bundle: .module))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var destinationChip: some View {
        if let destination = viewModel.activeDestination, !destination.isEmpty {
            Text(destination)
                .lineLimit(1)
                .help(LumiPluginLocalization.string("Target platform for current editor semantic context", bundle: .module))
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
                Text(LumiPluginLocalization.string("Xcode Context", bundle: .module))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                buildStatusBadge
            }

            detailRow(LumiPluginLocalization.string("Scheme", bundle: .module), viewModel.activeScheme ?? LumiPluginLocalization.string("Not Selected", bundle: .module))
            detailRow(LumiPluginLocalization.string("Configuration", bundle: .module), viewModel.activeConfiguration ?? LumiPluginLocalization.string("Not Selected", bundle: .module))
            detailRow(LumiPluginLocalization.string("Destination", bundle: .module), viewModel.activeDestination ?? LumiPluginLocalization.string("Undetermined", bundle: .module))
            detailRow(LumiPluginLocalization.string("Build Context", bundle: .module), viewModel.buildContextStatusDescription)

            HStack {
                Spacer()
                Button {
                    viewModel.resyncBuildContext()
                } label: {
                    if viewModel.isResyncingBuildContext {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LumiPluginLocalization.string("Re-resolving...", bundle: .module))
                        }
                    } else {
                        Text(LumiPluginLocalization.string("Re-resolve Build Context", bundle: .module))
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
                .disabled(viewModel.isResyncingBuildContext)
            }

            Divider()

            if let snapshot = viewModel.latestEditorSnapshot {
                detailRow(LumiPluginLocalization.string("Workspace", bundle: .module), snapshot.workspaceName)
                detailRow(LumiPluginLocalization.string("Current File", bundle: .module), snapshot.currentFilePath ?? LumiPluginLocalization.string("No File Open", bundle: .module))
                detailRow(LumiPluginLocalization.string("Preferred Target", bundle: .module), snapshot.currentFileTarget ?? LumiPluginLocalization.string("Undetermined", bundle: .module))
                detailRow(
                    LumiPluginLocalization.string("Matched Targets", bundle: .module),
                    snapshot.currentFileMatchedTargets.isEmpty ? LumiPluginLocalization.string("None", bundle: .module) : snapshot.currentFileMatchedTargets.joined(separator: ", ")
                )
                detailRow(
                    LumiPluginLocalization.string("Scheme Targets", bundle: .module),
                    snapshot.activeSchemeBuildableTargets.isEmpty ? LumiPluginLocalization.string("None", bundle: .module) : snapshot.activeSchemeBuildableTargets.joined(separator: ", ")
                )
                if !viewModel.semanticReport.reasons.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LumiPluginLocalization.string("Semantic Availability", bundle: .module))
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(viewModel.semanticReport.reasons) { reason in
                            reasonRow(reason)
                        }
                    }
                }
            } else {
                Text(LumiPluginLocalization.string("No editor context snapshot available.", bundle: .module))
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
                Text(LumiPluginLocalization.string("File Not Registered in Project", bundle: .module))
                    .font(.headline)
            }

            Text(
                String(
                    format: LumiPluginLocalization.string("\"%@\" is not bound to any compilation target. Cross-file semantic navigation may be unavailable.", bundle: .module),
                    fileName
                )
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(LumiPluginLocalization.string("Got It", bundle: .module), action: onDismiss)
                    .buttonStyle(.bordered)

                Button(LumiPluginLocalization.string("Open in Xcode", bundle: .module)) {
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
