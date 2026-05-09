import SwiftUI
import XcodeKit

/// Xcode 项目状态栏尾部视图
struct XcodeStatusBarTrailingView: View {
    @StateObject private var viewModel = XcodeProjectStatusBarViewModel()

    var body: some View {
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
    }
}

// MARK: - Detail View

struct XcodeStatusBarDetailView: View {
    @ObservedObject var viewModel: XcodeProjectStatusBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text(String(localized: "Xcode Build Context", table: "EditorXcodePlugin"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                buildStatusBadge
            }

            Divider()

            if let snapshot = viewModel.latestEditorSnapshot {
                infoSection(snapshot: snapshot)
            } else {
                Text(String(localized: "No editor context snapshot available.", table: "EditorXcodePlugin"))
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
                            Text(String(localized: "Re-resolving...", table: "EditorXcodePlugin"))
                        }
                    } else {
                        Label(
                            String(localized: "Re-resolve", table: "EditorXcodePlugin"),
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
                String(localized: "Scheme", table: "EditorXcodePlugin"),
                viewModel.activeScheme ?? String(localized: "Not Selected", table: "EditorXcodePlugin")
            )
            detailRow(
                String(localized: "Configuration", table: "EditorXcodePlugin"),
                viewModel.activeConfiguration ?? String(localized: "Not Selected", table: "EditorXcodePlugin")
            )
            detailRow(
                String(localized: "Destination", table: "EditorXcodePlugin"),
                viewModel.activeDestination ?? String(localized: "Undetermined", table: "EditorXcodePlugin")
            )
            detailRow(
                String(localized: "Workspace", table: "EditorXcodePlugin"),
                snapshot.workspaceName
            )
            detailRow(
                String(localized: "Current File", table: "EditorXcodePlugin"),
                snapshot.currentFilePath ?? String(localized: "No File Open", table: "EditorXcodePlugin")
            )
            detailRow(
                String(localized: "Preferred Target", table: "EditorXcodePlugin"),
                snapshot.currentFileTarget ?? String(localized: "Undetermined", table: "EditorXcodePlugin")
            )
        }

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
