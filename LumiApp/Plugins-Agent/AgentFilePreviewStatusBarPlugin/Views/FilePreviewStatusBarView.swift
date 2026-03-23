import SwiftUI
import MagicKit

/// 文件预览底部状态栏视图（类似 VS Code）
struct FilePreviewStatusBarView: View {
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

    /// 获取文件类型描述
    private var fileTypeDescription: String {
        SupportedFileType2.fileTypeDescription(for: fileExtension, fullFileName: fileName)
    }

    /// 获取当前文件内容
    private var fileContent: String {
        ProjectVM.selectedFileContent
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：内容类型标签（仅当选择了可预览文件时显示）
            if ProjectVM.isFileSelected && isPreviewableFile {
                Text(fileTypeDescription)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Color.semantic.info.opacity(0.15))
                    )
            }

            Spacer()

            // 右侧：字符数统计（仅当选择了可预览文件时显示）
            if ProjectVM.isFileSelected && isPreviewableFile {
                Text("\(fileContent.count) " + String(localized: "characters", table: "AgentFilePreviewStatusBar"))
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

#Preview {
    FilePreviewStatusBarView()
        .inRootView()
}