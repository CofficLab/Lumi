import MagicDiffView
import SwiftUI
import MagicKit

/// Git Commit 详情视图
///
/// 显示当前选中 commit 的完整信息，包括提交消息、作者、时间、
/// 变更统计，以及可交互的文件列表和 Diff 视图。
///
/// 参考 GitOK 的 GitDetail + FileList + FileDetail 实现，
/// 使用 HSplitView 将文件列表与 Diff 视图并排展示。
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

    /// 当前选中的文件（用于文件列表高亮）
    @State private var selectedFile: String?

    /// Diff 视图相关状态
    @State private var oldText: String = ""
    @State private var newText: String = ""
    @State private var loadingDiff: Bool = false
    @State private var diffTask: Task<Void, Never>?

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
            selectedFile = nil
            oldText = ""
            newText = ""
            loadCommitDetail()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            commitDetail = nil
            errorMessage = nil
            selectedFile = nil
            oldText = ""
            newText = ""
            loadCommitDetail()
        }
        .onChange(of: selectedFile) { _, newFile in
            loadFileDiff(file: newFile)
        }
    }

    // MARK: - Commit Detail Content

    private func commitDetailContent(_ detail: GitCommitDetail) -> some View {
        VStack(spacing: 0) {
            // 上半部分：commit 信息摘要（紧凑）
            commitSummarySection(detail)

            Divider()

            // 下半部分：文件列表 + Diff 视图
            if !detail.changedFiles.isEmpty {
                HSplitView {
                    // 左侧：文件列表
                    fileListSection(detail)
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                    // 右侧：Diff 视图
                    diffViewSection
                }
            } else {
                // 没有变更文件时显示提示
                noFilesView
            }
        }
    }

    // MARK: - Commit Summary Section

    private func commitSummarySection(_ detail: GitCommitDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 提交消息
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "circle.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 10))
                    .padding(.top, 2)

                Text(detail.message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()
            }

            // 元信息行：作者 + 时间 + Hash
            HStack(spacing: 12) {
                metaLabel(icon: "person.fill", value: detail.author)
                metaLabel(icon: "clock.fill", value: formattedDate(detail.date))
                hashLabel(detail)

                if let stats = detail.stats {
                    Spacer()
                    statsBadges(stats)
                }
            }

            // Commit Body（如果有）
            if !detail.body.isEmpty {
                Text(detail.body)
                    .font(.system(size: 11))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .padding(.leading, 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func metaLabel(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .lineLimit(1)
        }
    }

    private func hashLabel(_ detail: GitCommitDetail) -> some View {
        HStack(spacing: 2) {
            Text(detail.hash.prefix(7))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            Button {
                copyHash(detail.hash)
            } label: {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundColor(isCopied ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func statsBadges(_ stats: GitDiffStats) -> some View {
        HStack(spacing: 8) {
            statBadge(value: "\(stats.filesChanged)", label: "文件", color: AppUI.Color.semantic.textPrimary)
            statBadge(value: "+\(stats.insertions)", label: nil, color: .green)
            statBadge(value: "-\(stats.deletions)", label: nil, color: .red)
        }
    }

    private func statBadge(value: String, label: String?, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            if let label = label {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
        }
    }

    // MARK: - File List Section

    private func fileListSection(_ detail: GitCommitDetail) -> some View {
        VStack(spacing: 0) {
            // 文件列表标题栏
            HStack {
                Text("\(detail.changedFiles.count) 个文件")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 文件列表
            List(detail.changedFiles, id: \.self, selection: $selectedFile) { file in
                fileRow(file)
            }
            .listStyle(.plain)
        }
    }

    private func fileRow(_ file: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: fileIcon(for: file))
                .font(.system(size: 10))
                .foregroundColor(fileIconColor(for: file))

            Text(file)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            // 变更类型标记
            changeTypeBadge(for: file)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    /// 根据文件扩展名返回图标
    private func fileIcon(for file: String) -> String {
        let ext = (file as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text.fill"
        case "json": return "braces"
        case "md", "markdown": return "doc.text"
        case "yml", "yaml": return "doc.text"
        case "plist": return "gearshape"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "xcodeproj", "xcworkspace": return "hammer"
        case "html", "css": return "globe"
        case "py": return "doc.text.fill"
        case "rb": return "doc.text.fill"
        case "go": return "doc.text.fill"
        case "rs": return "doc.text.fill"
        default: return "doc.text"
        }
    }

    /// 文件图标颜色
    private func fileIconColor(for file: String) -> Color {
        let ext = (file as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "ts": return .yellow
        case "json": return .green
        case "md": return .blue
        default: return .secondary
        }
    }

    /// 根据 commit detail 的信息推断变更类型
    /// 注：由于 changedFiles 只包含文件名，无法精确判断变更类型，
    /// 这里统一显示为变更标记
    private func changeTypeBadge(for file: String) -> some View {
        Text("M")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.orange)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(3)
    }

    // MARK: - Diff View Section

    private var diffViewSection: some View {
        VStack(spacing: 0) {
            if let file = selectedFile {
                // 文件路径标题
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))

                    Text(file)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                if loadingDiff {
                    VStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("加载差异...")
                            .font(.system(size: 10))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if oldText.isEmpty && newText.isEmpty {
                    // 二进制文件或无法显示的内容
                    VStack(spacing: 6) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("无法显示此文件的差异")
                            .font(.system(size: 10))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MagicDiffView(
                        oldText: oldText,
                        newText: newText,
                        enableCollapsing: true,
                        minUnchangedLines: 3
                    )
                }
            } else {
                // 未选中文件
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("选择左侧文件查看差异")
                        .font(.system(size: 11))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - No Files View

    private var noFilesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.4))
            Text("此提交无文件变更")
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    // 自动选中第一个文件
                    self.selectedFile = detail.changedFiles.first
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

    /// 加载选中文件的 diff 内容
    private func loadFileDiff(file: String?) {
        diffTask?.cancel()

        guard let file = file,
              let hash = gitVM.selectedCommitHash,
              !projectVM.currentProjectPath.isEmpty else {
            oldText = ""
            newText = ""
            return
        }

        loadingDiff = true

        diffTask = Task.detached(priority: .userInitiated) {
            do {
                let (before, after) = try await GitService.shared.getCommitFileContentChange(
                    path: projectVM.currentProjectPath,
                    hash: hash,
                    file: file
                )

                if Task.isCancelled { return }

                await MainActor.run {
                    guard self.selectedFile == file else { return }
                    self.oldText = before ?? ""
                    self.newText = after ?? ""
                    self.loadingDiff = false
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    self.oldText = ""
                    self.newText = ""
                    self.loadingDiff = false
                }

                GitCommitDetailPlugin.logger.error("加载文件 diff 失败: \(error.localizedDescription)")
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
        .frame(width: 700, height: 600)
}
