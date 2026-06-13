import SwiftUI
import SuperLogKit
import LumiUI
import XcodeKit
import LumiCoreKit

/// Xcode 项目状态栏尾部视图
public struct XcodeStatusBarTrailingView: View, SuperLog {
    public nonisolated static let emoji = "🔨"

    @StateObject private var viewModel = XcodeProjectStatusBarViewModel.shared

    public var body: some View {
        Group {
            if viewModel.isXcodeProject {
                StatusBarHoverContainer(
                    detailView: XcodeStatusBarDetailView(viewModel: viewModel),
                    popoverWidth: 440,
                    id: "lumi-xcode-status-trailing"
                ) {
                    HStack(spacing: 4) {
                        if viewModel.isIndexing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                        } else {
                            Circle()
                                .fill(viewModel.semanticStatusColor)
                                .frame(width: 7, height: 7)
                        }

                        Text(viewModel.semanticStatusText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
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
}

// MARK: - Detail View

public struct XcodeStatusBarDetailView: View {
    @ObservedObject var viewModel: XcodeProjectStatusBarViewModel

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text(LumiPluginLocalization.string("Xcode Build Context", bundle: .module))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                buildStatusBadge
            }

            Divider()

            if let snapshot = viewModel.latestEditorSnapshot {
                infoSection(snapshot: snapshot)
            } else {
                Text(LumiPluginLocalization.string("No editor context snapshot available.", bundle: .module))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Divider()

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
                        Label(
                            LumiPluginLocalization.string("Re-resolve", bundle: .module),
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
                .disabled(viewModel.isResyncingBuildContext)
            }
        }
    }

    private var buildStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.semanticStatusColor)
                .frame(width: 7, height: 7)
            Text(viewModel.semanticStatusText)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func infoSection(snapshot: XcodeEditorContextSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(
                LumiPluginLocalization.string("Scheme", bundle: .module),
                viewModel.activeScheme ?? LumiPluginLocalization.string("Not Selected", bundle: .module)
            )
            detailRow(
                LumiPluginLocalization.string("Configuration", bundle: .module),
                viewModel.activeConfiguration ?? LumiPluginLocalization.string("Not Selected", bundle: .module)
            )
            detailRow(
                LumiPluginLocalization.string("Destination", bundle: .module),
                viewModel.activeDestination ?? LumiPluginLocalization.string("Undetermined", bundle: .module)
            )
            detailRow(
                LumiPluginLocalization.string("Workspace", bundle: .module),
                snapshot.workspaceName
            )
            detailRow(
                LumiPluginLocalization.string("Current File", bundle: .module),
                snapshot.currentFilePath ?? LumiPluginLocalization.string("No File Open", bundle: .module)
            )
            detailRow(
                LumiPluginLocalization.string("Preferred Target", bundle: .module),
                snapshot.currentFileTarget ?? LumiPluginLocalization.string("Undetermined", bundle: .module)
            )
        }

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

#Preview("Xcode Status Bar Trailing") {
    HStack {
        XcodeStatusBarTrailingView()
    }
    .padding()
    .frame(height: 30)
    .inRootView()
}
