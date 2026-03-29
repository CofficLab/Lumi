import MagicKit
import SwiftUI

/// 文件预览底部状态栏视图（类似 VS Code）
struct FilePreviewStatusBarView: View {
    @EnvironmentObject var ProjectVM: ProjectVM

    /// 当前文件内容（本地加载，用于统计）
    @State private var fileContent: String = ""
    @State private var canPreviewCurrentFile: Bool = false
    private static let textProbeBytes = 8192

    /// 获取当前文件扩展名
    private var fileExtension: String {
        guard let url = ProjectVM.selectedFileURL else { return "" }
        return url.pathExtension.lowercased()
    }

    /// 获取当前文件完整名称
    private var fileName: String {
        guard let url = ProjectVM.selectedFileURL else { return "" }
        return url.lastPathComponent
    }

    /// 获取文件类型描述
    private var fileTypeDescription: String {
        SupportedFileType2.fileTypeDescription(for: fileExtension, fullFileName: fileName)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：内容类型标签（仅当选择了可预览文件时显示）
            if ProjectVM.isFileSelected && canPreviewCurrentFile {
                Text(fileTypeDescription)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppUI.Color.semantic.info.opacity(0.15))
                    )
            }

            Spacer()

            // 右侧：字符数统计（仅当选择了可预览文件时显示）
            if ProjectVM.isFileSelected && canPreviewCurrentFile {
                Text("\(fileContent.count) " + String(localized: "characters", table: "AgentFilePreviewStatusBar"))
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onChange(of: ProjectVM.selectedFileURL) { _, newURL in
            loadFileContent(from: newURL)
        }
        .onAppear {
            loadFileContent(from: ProjectVM.selectedFileURL)
        }
    }

    // MARK: - Actions

    private func loadFileContent(from url: URL?) {
        guard let url = url else {
            fileContent = ""
            canPreviewCurrentFile = false
            return
        }

        // 检查是否是目录
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            fileContent = ""
            canPreviewCurrentFile = false
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
                    }
                    return
                }

                var usedEncoding = String.Encoding.utf8
                let content = try String(contentsOf: url, usedEncoding: &usedEncoding)
                await MainActor.run {
                    guard ProjectVM.selectedFileURL == selectedURL else { return }
                    self.fileContent = content
                    self.canPreviewCurrentFile = true
                }
            } catch {
                await MainActor.run {
                    guard ProjectVM.selectedFileURL == selectedURL else { return }
                    self.fileContent = ""
                    self.canPreviewCurrentFile = false
                }
            }
        }
    }

    private func isLikelyTextFile(url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

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

// MARK: - Preview

#Preview {
    FilePreviewStatusBarView()
        .inRootView()
}
