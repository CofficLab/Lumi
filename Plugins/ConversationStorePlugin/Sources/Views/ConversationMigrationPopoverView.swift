import SwiftUI

/// 会话迁移 popover 详情视图
///
/// 点击状态栏的迁移图标后弹出,展示会话迁移的详情:阶段、读取/导入的会话数、耗时。
/// 订阅 `ConversationMigrationProgressStore`,进度变化时自动刷新。
///
/// 状态栏本身只显示一个静态图标(由 StatusBarItem.systemImage 渲染),不在此视图内。
struct ConversationMigrationPopoverView: View {
    @ObservedObject private var progress = ConversationMigrationProgressStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if progress.readCount > 0 || progress.importedCount > 0 {
                statsSection
            }

            if progress.isActive {
                footer
            }
        }
        .padding(16)
        .frame(minWidth: 260)
    }

    // MARK: - Sections

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: phaseIcon)
                .foregroundStyle(phaseColor)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(phaseTitle)
                    .font(.system(size: 13, weight: .semibold))
                Text("历史会话迁移")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            statRow(label: "读取", value: progress.readCount)
            statRow(label: "导入", value: progress.importedCount)
        }
    }

    @ViewBuilder
    private func statRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value) 条会话")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let startedAt = progress.startedAt {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("已用时 \(elapsedText(since: startedAt))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Derived

    private var phaseIcon: String {
        switch progress.phase {
        case .idle: "tray"
        case .running: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var phaseColor: Color {
        switch progress.phase {
        case .idle: .secondary
        case .running: .accentColor
        case .completed: .green
        case .failed: .orange
        }
    }

    private var phaseTitle: String {
        switch progress.phase {
        case .idle: "等待开始"
        case .running: "正在迁移…"
        case .completed: "迁移完成"
        case .failed: "迁移失败"
        }
    }

    private func elapsedText(since startedAt: Date) -> String {
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < 60 {
            return String(format: "%.0f 秒", elapsed)
        }
        return String(format: "%.1f 分钟", elapsed / 60)
    }
}
