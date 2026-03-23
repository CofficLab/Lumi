import MagicKit
import SwiftUI

/// 文件预览视图
struct FilePreviewView: View {
    @EnvironmentObject var ProjectVM: ProjectVM

    /// 判断当前选择的文件是否为可预览的类型
    private var isPreviewableFile: Bool {
        guard let url = ProjectVM.selectedFileURL else { return false }
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()

        // 首先检查是否是 Git 配置文件（通过完整文件名判断）
        if SupportedFileType.isPreviewable(fileName: fileName) {
            return true
        }

        // 然后通过扩展名判断
        return SupportedFileType.isPreviewable(fileExtension)
    }

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

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // 文件预览内容
            if ProjectVM.isFileSelected {
                if isPreviewableFile {
                    filePreviewContent
                } else {
                    FilePreviewUnsupportedView(fileName: "\(ProjectVM.selectedFileURL?.lastPathComponent ?? "")")
                }
            } else {
                FilePreviewEmptyStateView()
            }
        }
        .padding(.vertical, 8)
        .background(DesignTokens.Material.glassThick)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "doc.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text(String(localized: "File Preview", table: "AgentFilePreview"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()

            // 清除选择按钮
            Button(action: clearSelection) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - File Preview Content

    private var filePreviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // 文件信息
                fileInfoSection

                Divider()
                    .background(Color.white.opacity(0.1))

                // 文件内容
                fileContentSection
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 文件名
            Text(ProjectVM.selectedFileURL?.lastPathComponent ?? "")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .lineLimit(2)

            // 文件路径
            Text(ProjectVM.selectedFilePath)
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileContentSection: some View {
        FileContentSectionView(
            content: ProjectVM.selectedFileContent,
            fileExtension: fileExtension,
            fileName: fileName
        )
    }
}

// MARK: - Actions

extension FilePreviewView {
    func clearSelection() {
        self.ProjectVM.clearFileSelection()
    }
}

// MARK: - Preview

#Preview {
    FilePreviewView()
        .inRootView()
}