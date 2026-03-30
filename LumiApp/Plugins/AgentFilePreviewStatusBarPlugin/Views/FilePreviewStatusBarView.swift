import MagicKit
import SwiftUI

/// 文件预览底部状态栏视图（类似 VS Code）
struct FilePreviewStatusBarView: View {
    @EnvironmentObject var ProjectVM: ProjectVM

    /// 当前文件内容（本地加载，用于统计）
    @State private var fileContent: String = ""
    @State private var canPreviewCurrentFile: Bool = false
    @State private var fileInfo: FileInfo?

    private static let textProbeBytes = 8192

    private var selectedFilePath: String {
        ProjectVM.selectedFileURL?.path ?? ""
    }

    var body: some View {
        Group {
            if let fileInfo = fileInfo {
                StatusBarHoverContainer(
                    detailView: FilePreviewDetailView(fileInfo: fileInfo),
                    id: "file-preview-status"
                ) {
                    contentView
                }
            } else {
                StatusBarHoverContainer(
                    id: "file-preview-status"
                ) {
                    contentView
                }
            }
        }
        .onChange(of: ProjectVM.selectedFileURL) { _, newURL in
            loadFileContent(from: newURL)
        }
        .onAppear {
            loadFileContent(from: ProjectVM.selectedFileURL)
        }
    }

    private var contentView: some View {
        HStack(spacing: 12) {
            // 当前文件路径
            if ProjectVM.isFileSelected {
                Text(selectedFilePath)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func loadFileContent(from url: URL?) {
        guard let url = url else {
            fileContent = ""
            canPreviewCurrentFile = false
            fileInfo = nil
            return
        }

        // 检查是否是目录
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            fileContent = ""
            canPreviewCurrentFile = false
            fileInfo = nil
            return
        }

        let selectedURL = url
        Task {
            do {
                guard try isLikelyTextFile(url: url) else {
                    await MainActor.run {
                        guard ProjectVM.selectedFileURL == selectedURL else { return }
                        self.fileContent = ""
                        self.canPreviewCurrentFile = false
                        self.fileInfo = nil
                    }
                    return
                }

                var usedEncoding = String.Encoding.utf8
                let content = try String(contentsOf: url, usedEncoding: &usedEncoding)

                // 获取文件信息
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0
                let modificationDate = attributes?[.modificationDate] as? Date

                await MainActor.run {
                    guard ProjectVM.selectedFileURL == selectedURL else { return }
                    self.fileContent = content
                    self.canPreviewCurrentFile = true
                    self.fileInfo = FileInfo(
                        path: url.path,
                        size: fileSize,
                        lineCount: content.components(separatedBy: .newlines).count,
                        modificationDate: modificationDate,
                        encoding: usedEncoding
                    )
                }
            } catch {
                await MainActor.run {
                    guard ProjectVM.selectedFileURL == selectedURL else { return }
                    self.fileContent = ""
                    self.canPreviewCurrentFile = false
                    self.fileInfo = nil
                }
            }
        }
    }

    private func isLikelyTextFile(url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            do {
                try handle.close()
            } catch {
                // 忽略关闭错误
            }
        }

        let sample = try handle.read(upToCount: Self.textProbeBytes) ?? Data()
        if sample.isEmpty { return true }
        if sample.contains(0) { return false }

        var controlByteCount = 0
        for byte in sample {
            if byte == 0x09 || byte == 0x0A || byte == 0x0D {
                continue
            }
            if byte < 0x20 {
                controlByteCount += 1
            }
        }

        let ratio = Double(controlByteCount) / Double(sample.count)
        return ratio < 0.05
    }
}

// MARK: - File Preview Detail View

/// 文件预览详情视图（在 popover 中显示）
struct FilePreviewDetailView: View {
    let fileInfo: FileInfo

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("文件信息")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            Divider()

            // 文件信息网格
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                FilePreviewInfoRow(title: "文件路径", value: (fileInfo.path as NSString).lastPathComponent)
                FilePreviewInfoRow(title: "文件大小", value: ByteCountFormatter.string(fromByteCount: fileInfo.size, countStyle: .file))
                FilePreviewInfoRow(title: "行数", value: "\(fileInfo.lineCount)")
                FilePreviewInfoRow(title: "编码", value: encodingName(fileInfo.encoding))
            }
        }
    }

    private func encodingName(_ encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .ascii: return "ASCII"
        default: return "其他"
        }
    }
}

/// 文件预览信息行
struct FilePreviewInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - FileInfo Model

/// 文件信息模型
struct FileInfo {
    let path: String
    let size: Int64
    let lineCount: Int
    let modificationDate: Date?
    let encoding: String.Encoding
}

// MARK: - Preview

#Preview("FilePreviewStatusBarView") {
    let contextService = ContextService()
    let llmService = LLMService()
    let projectVM = ProjectVM(contextService: contextService, llmService: llmService)

    FilePreviewStatusBarView()
        .environmentObject(projectVM)
        .frame(height: 50)
}

#Preview("Detail View") {
    FilePreviewDetailView(fileInfo: FileInfo(
        path: "/Users/test/Lumi/App.swift",
        size: 12345,
        lineCount: 150,
        modificationDate: Date(),
        encoding: .utf8
    ))
    .frame(width: 300)
}
