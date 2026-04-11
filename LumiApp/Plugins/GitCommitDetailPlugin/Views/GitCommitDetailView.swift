import SwiftUI
import MagicKit

/// Git Commit 详情视图
///
/// 显示当前选中 commit 的完整信息，参考 GitOK 的 CommitInfoView。
/// 当 GitVM 中选中的 commit 变化时自动刷新。
struct GitCommitDetailView: View {
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject var gitVM: GitVM

    /// 当前加载的 commit 详情
    @State private var commitDetail: GitCommitDetail?

    /// 是否正在加载
    @State private var loading = false

    /// 错误信息
    @State private var errorMessage: String?

    /// Hash 是否已复制
    @State private var isCopied = false

    /// 当前加载任务
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            if let detail = commitDetail {
                commitDetailContent(detail)
            } else if loading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if projectVM.isProjectSelected {
                noSelectionView
            } else {
                noProjectView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadCommitDetail()
        }
        .onChange(of: gitVM.selectedCommitHash) { _, _ in
            loadCommitDetail()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            commitDetail = nil
            errorMessage = nil
            loadCommitDetail()
        }
    }

    // MARK: - Commit Detail Content

    private func commitDetailContent(_ detail: GitCommitDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: 提交消息头部
                commitMessageSection(detail)

                Divider()
                    .padding(.vertical, 8)

                // MARK: Commit Body（如果有）
                if !detail.body.isEmpty {
                    commitBodySection(detail)
                    Divider()
                        .padding(.vertical, 8)
                }

                // MARK: 详细信息行
                commitMetaSection(detail)

                Divider()
                    .padding(.vertical, 8)

                // MARK: 变更统计
                if let stats = detail.stats {
                    commitStatsSection(stats)
                    Divider()
                        .padding(.vertical, 8)
                }

                // MARK: 变更文件列表
                if !detail.changedFiles.isEmpty {
                    commitFilesSection(detail)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Commit Message Section

    private func commitMessageSection(_ detail: GitCommitDetail) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.circle.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 12))
                .padding(.top, 3)

            Text(detail.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .lineLimit(5)
                .textSelection(.enabled)

            Spacer()
        }
    }

    // MARK: - Commit Body Section

    private func commitBodySection(_ detail: GitCommitDetail) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.alignleft")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
                .padding(.top, 2)

            Text(detail.body)
                .font(.system(size: 12))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .lineLimit(20)
                .textSelection(.enabled)

            Spacer()
        }
    }

    // MARK: - Commit Meta Section

    private func commitMetaSection(_ detail: GitCommitDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 作者
            metaRow(icon: "person.circle.fill", label: "Author", value: "\(detail.author) <\(detail.email)>")

            // 时间
            metaRow(icon: "clock.fill", label: "Date", value: formattedDate(detail.date))

            // Hash（可复制）
            hashRow(detail)
        }
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.system(size: 11))
                .frame(width: 14)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 42, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .lineLimit(1)
                .textSelection(.enabled)

            Spacer()
        }
    }

    private func hashRow(_ detail: GitCommitDetail) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "number.circle.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
                .frame(width: 14)

            Text("Hash")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 42, alignment: .leading)

            Text(detail.hash.prefix(7))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer()

            // 复制按钮
            Button {
                copyHash(detail.hash)
            } label: {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(isCopied ? .green : AppUI.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .help(isCopied ? "已复制" : "复制完整 Hash")
        }
    }

    // MARK: - Commit Stats Section

    private func commitStatsSection(_ stats: GitDiffStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("变更统计")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            HStack(spacing: 16) {
                statBadge(
                    icon: "doc.fill",
                    value: "\(stats.filesChanged)",
                    label: "文件"
                )

                statBadge(
                    icon: "arrow.up.circle.fill",
                    value: "+\(stats.insertions)",
                    label: "插入",
                    color: .green
                )

                statBadge(
                    icon: "arrow.down.circle.fill",
                    value: "-\(stats.deletions)",
                    label: "删除",
                    color: .red
                )
            }
        }
    }

    private func statBadge(icon: String, value: String, label: String, color: Color = AppUI.Color.semantic.textPrimary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
    }

    // MARK: - Commit Files Section

    private func commitFilesSection(_ detail: GitCommitDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("变更文件")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            ForEach(detail.changedFiles, id: \.self) { file in
                fileRow(file)
            }
        }
    }

    private func fileRow(_ file: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text(file)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.regular)
            Text("正在加载...")
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange.opacity(0.6))
            Text("加载失败")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noSelectionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.circle")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text("请在左侧选择一个 Commit")
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noProjectView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text("请先选择一个项目")
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadCommitDetail() {
        let hash = gitVM.selectedCommitHash
        let path = projectVM.currentProjectPath

        guard let hash = hash, !path.isEmpty else {
            commitDetail = nil
            loading = false
            errorMessage = nil
            return
        }

        // 取消之前的任务
        loadTask?.cancel()
        loading = true
        errorMessage = nil

        loadTask = Task {
            do {
                let detail = try await GitService.shared.getCommitDetail(
                    path: path,
                    hash: hash
                )

                if Task.isCancelled { return }

                await MainActor.run {
                    // 确保结果与当前选中一致
                    guard self.gitVM.selectedCommitHash == hash else { return }
                    self.commitDetail = detail
                    self.loading = false
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    self.commitDetail = nil
                    self.loading = false
                    self.errorMessage = error.localizedDescription
                }

                GitCommitDetailPlugin.logger.error("加载 commit 详情失败: \(error.localizedDescription)")
            }
        }
    }

    private func copyHash(_ hash: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hash, forType: .string)
        #endif

        withAnimation(.spring()) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring()) {
                isCopied = false
            }
        }
    }

    // MARK: - Date Formatting

    private func formattedDate(_ dateString: String) -> String {
        let formatters = DateParseHelper.formatHandlers

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                displayFormatter.locale = Locale(identifier: "en_US_POSIX")
                return displayFormatter.string(from: date)
            }
        }

        return dateString
    }
}

// MARK: - Preview

#Preview {
    GitCommitDetailView()
        .inRootView()
        .frame(width: 400, height: 600)
}
