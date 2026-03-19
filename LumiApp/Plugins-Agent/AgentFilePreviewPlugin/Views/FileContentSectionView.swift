import SwiftUI
import MagicKit

/// 文件内容渲染视图
struct FileContentSectionView: View {
    let content: String
    let fileExtension: String
    let fileName: String

    /// 判断是否为 Markdown 文件
    private var isMarkdownFile: Bool {
        SupportedFileType.isMarkdownFile(fileExtension)
    }

    /// 获取文件类型描述
    private var fileTypeDescription: String {
        SupportedFileType.fileTypeDescription(for: fileExtension, fullFileName: fileName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 文件内容：根据文件类型使用不同的渲染方式
            contentBody
        }
    }

    /// 文件内容渲染
    @ViewBuilder
    private var contentBody: some View {
        if isMarkdownFile {
            // Markdown 文件使用 Markdown 渲染
            markdownContentView
        } else {
            // 其他可预览文件（代码、文本）使用等宽字体显示
            plainTextView
        }
    }

    /// Markdown 内容视图
    private var markdownContentView: some View {
        ScrollView {
            NativeMarkdownContent(
                content: content,
                chatListIsActivelyScrolling: false
            )
                .font(.system(size: 10))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    /// 纯文本内容视图（代码等）
    private var plainTextView: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

#Preview("Markdown 内容") {
    FileContentSectionView(content: "# Hello World\n\n这是一段 **Markdown** 内容。", fileExtension: "md", fileName: "README.md")
        .frame(width: 300, height: 200)
        .padding()
}

#Preview("代码内容") {
    FileContentSectionView(content: "func hello() {\n    print(\"Hello World\")\n}", fileExtension: "swift", fileName: "main.swift")
        .frame(width: 300, height: 200)
        .padding()
}

#Preview("Git 配置") {
    FileContentSectionView(content: "*.pyc\n.DS_Store\n", fileExtension: "", fileName: ".gitignore")
        .frame(width: 300, height: 200)
        .padding()
}
