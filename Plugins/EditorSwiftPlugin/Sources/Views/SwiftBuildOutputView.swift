import AppKit
import LumiKernel
import LumiUI
import SwiftUI
import XcodeKit

struct SwiftBuildOutputView: View {
    @LumiTheme private var theme
    @ObservedObject var buildRunManager: SwiftBuildRunManager
    var onClose: (() -> Void)?
    @State private var didCopyOutput = false

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()
            if !buildRunManager.hasAnyStageOutput {
                emptyState
            } else {
                VStack(spacing: 0) {
                    if !buildRunManager.logStages.isEmpty {
                        stagePicker
                        Divider()
                    }

                    if !buildRunManager.issues.isEmpty, buildRunManager.selectedLogStage == .build {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(buildRunManager.issues) { issue in
                                    issueRow(issue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: min(issuesPanelHeight, 220))

                        if !selectedStageOutputText.isEmpty {
                            Divider()
                        }
                    }

                    if buildRunManager.omittedLineCount > 0 {
                        omittedLinesBanner
                        Divider()
                    }

                    if selectedStageOutputText.isEmpty {
                        stageEmptyState
                    } else {
                        BuildLogTextView(
                            text: selectedStageOutputText,
                            autoScrollToBottom: buildRunManager.isActive
                                && buildRunManager.selectedLogStage == activeLogStage
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    private var selectedStageOutputText: String {
        buildRunManager.outputText
    }

    private var activeLogStage: SwiftBuildRunLogStage {
        switch buildRunManager.phase {
        case .preflighting:
            return .preflight
        case .building:
            return .build
        case .launching:
            return .launch
        default:
            return buildRunManager.selectedLogStage
        }
    }

    private var stagePicker: some View {
        HStack(spacing: 6) {
            ForEach(buildRunManager.logStages) { record in
                stageButton(record)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.textSecondary.opacity(0.05))
    }

    private func stageButton(_ record: SwiftBuildRunStageRecord) -> some View {
        let isSelected = buildRunManager.selectedLogStage == record.stage

        return Button {
            buildRunManager.selectLogStage(record.stage)
        } label: {
            HStack(spacing: 5) {
                stageStatusIcon(for: record.status, isSelected: isSelected)
                Text(buildRunManager.localizedTitle(for: record.stage))
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? theme.textSecondary.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
    }

    @ViewBuilder
    private func stageStatusIcon(for status: SwiftBuildRunStageStatus, isSelected: Bool) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        case .active:
            ProgressView()
                .scaleEffect(0.45)
                .frame(width: 10, height: 10)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(hex: "30D158"))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(hex: "FF453A"))
        case .skipped:
            Image(systemName: "minus.circle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var issuesPanelHeight: CGFloat {
        CGFloat(min(buildRunManager.issues.count, 8)) * 44
    }

    private var omittedLinesBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "ellipsis.rectangle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            Text(
                String(
                    format: LumiPluginLocalization.string("%lld earlier log lines omitted", bundle: .module),
                    buildRunManager.omittedLineCount
                )
            )
            .font(.system(size: 10))
            .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(theme.textSecondary.opacity(0.06))
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            if buildRunManager.isActive {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(activeTitle)
                    .font(.system(size: 11, weight: .medium))
            } else if buildRunManager.phase == .cancelled {
                Label(LumiPluginLocalization.string("Cancelled", bundle: .module), systemImage: "stop.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            } else if buildRunManager.errorCount > 0 {
                Label(
                    "\(buildRunManager.errorCount) \(LumiPluginLocalization.string("errors", bundle: .module))",
                    systemImage: "xmark.circle.fill"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "FF453A"))
            } else if buildRunManager.phase == .succeeded {
                Label(LumiPluginLocalization.string("Run succeeded", bundle: .module), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "30D158"))
            } else if buildRunManager.phase == .failed {
                Label(LumiPluginLocalization.string("Run failed", bundle: .module), systemImage: "xmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "FF453A"))
            }

            Spacer()

            if hasCopyableContent {
                Button {
                    copyOutput()
                } label: {
                    Label(
                        didCopyOutput
                            ? LumiPluginLocalization.string("Copied", bundle: .module)
                            : copyButtonTitle,
                        systemImage: didCopyOutput ? "checkmark.circle.fill" : "doc.on.doc"
                    )
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(didCopyOutput ? Color(hex: "30D158") : theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(copyButtonHelp)
            }

            if buildRunManager.isActive {
                Button {
                    buildRunManager.cancel()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
                .help(LumiPluginLocalization.string("Stop", bundle: .module))
            }

            if buildRunManager.lastDuration > 0 {
                Text(String(format: "%.1fs", buildRunManager.lastDuration))
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textTertiary)
                .help(LumiPluginLocalization.string("Close", bundle: .module))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var hasCopyableContent: Bool {
        buildRunManager.hasAnyStageOutput || buildRunManager.lastError != nil
    }

    private var copyButtonTitle: String {
        if buildRunManager.errorCount > 0
            || buildRunManager.phase == .failed
            || buildRunManager.lastError != nil {
            return LumiPluginLocalization.string("Copy Error", bundle: .module)
        }
        return LumiPluginLocalization.string("Copy Log", bundle: .module)
    }

    private var copyButtonHelp: String {
        copyButtonTitle
    }

    private func copyOutput() {
        let text = buildRunManager.fullLogTextForCopy()
        guard !text.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            didCopyOutput = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopyOutput = false
            }
        }
    }

    private var emptyState: some View {
        Text(LumiPluginLocalization.string("No build output yet", bundle: .module))
            .font(.system(size: 12))
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }

    private var stageEmptyState: some View {
        Text(
            String(
                format: LumiPluginLocalization.string("No output for stage %@", bundle: .module),
                buildRunManager.localizedTitle(for: buildRunManager.selectedLogStage)
            )
        )
        .font(.system(size: 12))
        .foregroundStyle(theme.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var activeTitle: String {
        switch buildRunManager.phase {
        case .preflighting:
            return LumiPluginLocalization.string("Preparing…", bundle: .module)
        case .building:
            return LumiPluginLocalization.string("Building…", bundle: .module)
        case .launching:
            return LumiPluginLocalization.string("Launching…", bundle: .module)
        default:
            return LumiPluginLocalization.string("Running…", bundle: .module)
        }
    }

    private func issueRow(_ issue: SwiftBuildIssue) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(issue.severity == .error ? Color(hex: "FF453A") : Color(hex: "FF9F0A"))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                if let file = issue.file, let line = issue.line {
                    Text("\(file):\(line)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
                Text(issue.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
