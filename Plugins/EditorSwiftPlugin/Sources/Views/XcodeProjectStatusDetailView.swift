import AppKit
import LumiKernel
import SwiftUI
import XcodeKit

public struct XcodeProjectStatusDetailView: View {
    @ObservedObject var viewModel: XcodeProjectStatusBarViewModel
    @State private var copiedSemanticError = false
    @State private var copiedIndexLog = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LumiPluginLocalization.string("Xcode Context", bundle: .module))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                buildStatusBadge
            }

            detailRow(LumiPluginLocalization.string("Build Context", bundle: .module), viewModel.buildContextStatusDescription)
            detailRow(LumiPluginLocalization.string("Semantic Index", bundle: .module), viewModel.semanticStatusDescription)
            detailRow(LumiPluginLocalization.string("Capability Level", bundle: .module), viewModel.capabilityLevelDescription)
            if !viewModel.preflightIssues.isEmpty {
                detailRow(
                    LumiPluginLocalization.string("Preflight", bundle: .module),
                    viewModel.preflightIssues.joined(separator: "; ")
                )
            }
            toolsToolbar
            if let failureReason = viewModel.semanticIndexFailureReason {
                semanticIndexErrorSection(failureReason)
            }
            if let logExcerpt = viewModel.semanticIndexLogExcerpt {
                semanticIndexLogSection(logExcerpt)
            }

            if let progress = viewModel.resolutionProgress {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    detailRow(
                        LumiPluginLocalization.string("Resolution Progress", bundle: .module),
                        XcodeProjectStatusPresentation.localizedResolutionProgressDetail(
                            progress,
                            now: context.date
                        )
                    )
                }
            } else if viewModel.isResolvingBuildContext {
                detailRow(
                    LumiPluginLocalization.string("Resolution Progress", bundle: .module),
                    LumiPluginLocalization.string("Resolving build context...", bundle: .module)
                )
            }

            if viewModel.isIndexing, let indexingTask = viewModel.indexingTask {
                detailRow(
                    LumiPluginLocalization.string("Indexing", bundle: .module),
                    XcodeProjectStatusPresentation.localizedIndexingTaskText(indexingTask)
                )
            }

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
        .onAppear { viewModel.detailPanelDidAppear() }
        .onDisappear { viewModel.detailPanelDidDisappear() }
    }

    private var buildStatusBadge: some View {
        Text(viewModel.buildContextStatusDescription)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)
    }

    private var toolsToolbar: some View {
        HStack(spacing: 10) {
            Text(LumiPluginLocalization.string("Tools", bundle: .module))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                viewModel.exportDiagnostics()
            } label: {
                Text(LumiPluginLocalization.string("Export Diagnostics", bundle: .module))
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.blue)

            Button {
                viewModel.openCacheDirectory()
            } label: {
                Text(LumiPluginLocalization.string("Open Cache Folder", bundle: .module))
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.blue)

            Button {
                viewModel.reindexNow()
            } label: {
                Text(LumiPluginLocalization.string("Reindex", bundle: .module))
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.blue)
            .disabled(viewModel.isResyncingBuildContext)

            Button {
                viewModel.clearIndexData()
            } label: {
                Text(LumiPluginLocalization.string("Clear Data", bundle: .module))
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.red)
            .disabled(viewModel.isResyncingBuildContext)
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

    @ViewBuilder
    private func semanticIndexErrorSection(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LumiPluginLocalization.string("Index Error Details", bundle: .module))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Text(reason)
                .font(.system(size: 11))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)

            HStack {
                Spacer()
                Button {
                    copyToPasteboard(reason)
                } label: {
                    Text(
                        copiedSemanticError
                            ? LumiPluginLocalization.string("Copied", bundle: .module)
                            : LumiPluginLocalization.string("Copy Error", bundle: .module)
                    )
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copiedSemanticError = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copiedSemanticError = false
        }
    }

    @ViewBuilder
    private func semanticIndexLogSection(_ logExcerpt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LumiPluginLocalization.string("Index Build Log", bundle: .module))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logExcerpt.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(logLineColor(line))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 180, maxHeight: 260)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.28), lineWidth: 1)
            )

            HStack {
                Spacer()
                Button {
                    copyIndexLog(logExcerpt)
                } label: {
                    Text(
                        copiedIndexLog
                            ? LumiPluginLocalization.string("Copied", bundle: .module)
                            : LumiPluginLocalization.string("Copy Log", bundle: .module)
                    )
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
            }
        }
    }

    private func copyIndexLog(_ logText: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
        copiedIndexLog = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copiedIndexLog = false
        }
    }

    private func logLineColor(_ line: String) -> Color {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("error:") || normalized.contains("error ") {
            return Color(red: 1.0, green: 0.45, blue: 0.45)
        }
        if normalized.contains("warning:") || normalized.contains("warning ") {
            return Color(red: 1.0, green: 0.84, blue: 0.45)
        }
        return Color.white.opacity(0.92)
    }

    private func color(for severity: XcodeSemanticAvailability.ReasonSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}
