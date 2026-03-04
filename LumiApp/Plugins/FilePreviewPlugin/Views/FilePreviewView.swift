import SwiftUI
import OSLog
import MagicKit

/// 文件预览视图
struct FilePreviewView: View {
    @EnvironmentObject var agentProvider: AgentProvider

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // 文件预览内容
            filePreviewContent
            
            Spacer()
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

            Text("文件预览")
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
            Text(agentProvider.selectedFileURL?.lastPathComponent ?? "")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .lineLimit(2)

            // 文件路径
            Text(agentProvider.selectedFilePath)
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileContentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 内容标签
            HStack {
                Text("内容")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                Spacer()

                // 字符数统计
                Text("\(agentProvider.selectedFileContent.count) 字符")
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }

            // 文件内容
            Text(agentProvider.selectedFileContent)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func clearSelection() {
        agentProvider.clearFileSelection()
    }
}

#Preview {
    FilePreviewView()
        .environmentObject(AgentProvider.shared)
        .inRootView("Preview")
}
