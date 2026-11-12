import LumiUI
import ProviderMessage
import SwiftUI

/// 后台任务通知卡片。
///
/// 展示任务状态、命令、输出路径，并提供「停止」按钮。
///
/// 载荷从消息 metadata 解析：通知消息是持久化的，用户过几天回看时进程早已
/// 结束，因此卡片必须能在**没有活进程**的情况下正确显示终态。
///
/// 任务还在跑时，卡片会轮询登记表刷新状态与尾部输出——这是用户唯一能看到
/// 「后台命令跑到哪了」的地方。
struct BackgroundTaskCardView: View {
    @LumiTheme private var theme

    /// 任务 ID。
    let taskID: String
    /// 消息里记录的任务状态（终态消息用；运行中消息用 `.running`）。
    let status: BackgroundTaskStatus
    /// 退出码。
    let exitCode: Int32?
    /// 输出文件路径。
    let outputPath: String
    /// 通知正文（用于展示命令与摘录）。
    let content: String
    /// 登记表：用于轮询实时状态与尾部输出。为 nil 时只显示静态信息。
    let registry: BackgroundTaskRegistry?

    /// 卡片当前显示的状态。
    @State private var liveStatus: BackgroundTaskStatus
    /// 卡片当前显示的尾部输出。
    @State private var liveTail: String
    /// 轮询任务。
    @State private var pollTask: Task<Void, Never>?

    init(
        taskID: String,
        status: BackgroundTaskStatus,
        exitCode: Int32?,
        outputPath: String,
        content: String,
        registry: BackgroundTaskRegistry?
    ) {
        self.taskID = taskID
        self.status = status
        self.exitCode = exitCode
        self.outputPath = outputPath
        self.content = content
        self.registry = registry
        self._liveStatus = State(initialValue: status)
        self._liveTail = State(initialValue: "")
    }

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Divider()
                    .overlay(theme.divider.opacity(0.6))

                detailRows

                if !liveTail.isEmpty {
                    tailSection
                }

                if liveStatus == .running {
                    action
                }
            }
        }
        .task { await startPollingIfNeeded() }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(pluginLocalization.string("Background Task"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(statusTitle)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Details

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow(
                icon: "number",
                title: pluginLocalization.string("Task ID"),
                value: taskID
            )
            detailRow(
                icon: "doc.text",
                title: pluginLocalization.string("Output File"),
                value: outputPath
            )
            if let exitCode {
                detailRow(
                    icon: "number.circle",
                    title: pluginLocalization.string("Exit Code"),
                    value: String(exitCode)
                )
            }
            if let command = parsedCommand, !command.isEmpty {
                detailRow(
                    icon: "terminal",
                    title: pluginLocalization.string("Command"),
                    value: command
                )
            }
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 68, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Tail

    private var tailSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pluginLocalization.string("Last Output"))
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)

            Text(liveTail)
                .font(.caption2.monospaced())
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(12)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Action

    private var action: some View {
        HStack {
            Spacer(minLength: 0)
            AppButton(
                pluginLocalization.string("Stop"),
                systemImage: "stop.circle",
                style: .secondary,
                size: .small
            ) {
                Task { @MainActor in
                    await registry?.stop(taskID: taskID)
                }
            }
        }
    }

    // MARK: - Polling

    /// 任务还在跑时轮询登记表，刷新状态与尾部输出。
    private func startPollingIfNeeded() async {
        guard status == .running, let registry else { return }
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                let record = await registry.task(for: taskID)
                if let record {
                    liveStatus = record.status
                    liveTail = await registry.outputTail(for: taskID, limit: 2_000)
                    if record.status != .running { return }
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Status

    private var statusTitle: String {
        switch liveStatus {
        case .running:
            return pluginLocalization.string("Running in background")
        case .completed:
            return pluginLocalization.string("Completed successfully")
        case .failed:
            return pluginLocalization.string("Failed")
        case .stopped:
            return pluginLocalization.string("Stopped")
        case .interrupted:
            return pluginLocalization.string("Interrupted")
        }
    }

    private var statusIcon: String {
        switch liveStatus {
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .stopped: return "stop.circle.fill"
        case .interrupted: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: SwiftUI.Color {
        switch liveStatus {
        case .running: return theme.primary
        case .completed: return theme.success
        case .failed: return theme.error
        case .stopped: return theme.textSecondary
        case .interrupted: return theme.warning
        }
    }

    /// 从通知正文里解析出命令原文。
    ///
    /// 通知正文格式固定，因此按行扫描 `Output file:` 之前的内容即为命令段落。
    /// 解析失败时返回 nil —— 卡片少一行信息，但不能因此渲染失败。
    private var parsedCommand: String? {
        guard let markerRange = content.range(of: "Output file:") else { return nil }
        let head = String(content[content.startIndex..<markerRange.lowerBound])
        let lines = head
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // 第一段是 "Background task <id> <status>."，命令在第二段。
        guard lines.count >= 2 else { return nil }
        return lines[1]
    }
}
