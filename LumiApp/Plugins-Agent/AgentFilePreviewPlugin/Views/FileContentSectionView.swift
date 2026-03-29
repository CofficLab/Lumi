import CodeEditor
import SwiftUI
import MagicKit

/// 文件内容渲染视图
struct FileContentSectionView: View {
    @Binding var content: String
    let fileExtension: String
    let fileName: String
    let theme: CodeEditor.ThemeName

    var body: some View {
        CodeEditor(source: $content, language: editorLanguage, theme: theme)
            .font(.system(size: 10, design: .monospaced))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var editorLanguage: CodeEditor.Language {
        let ext = fileExtension.lowercased()
        let name = fileName.lowercased()
        let candidates = languageCandidates(forExtension: ext, fileName: name)

        for candidate in candidates {
            if let match = CodeEditor.availableLanguages.first(where: { $0.rawValue == candidate }) {
                return match
            }
        }

        if let plaintext = CodeEditor.availableLanguages.first(where: { $0.rawValue == "plaintext" }) {
            return plaintext
        }

        return CodeEditor.availableLanguages.first ?? .swift
    }

    private func languageCandidates(forExtension ext: String, fileName: String) -> [String] {
        if [".gitignore", ".gitattributes", ".gitmodules"].contains(fileName) {
            return ["plaintext", "ini", "yaml", "markdown"]
        }

        switch ext {
        case "mdc":
            return ["markdown", "md"]
        case "h":
            return ["objectivec", "c", "cpp"]
        case "m":
            return ["objectivec", "matlab"]
        case "mm":
            return ["objectivec", "cpp"]
        case "kt", "kts":
            return ["kotlin"]
        case "pyw":
            return ["python"]
        case "tsx":
            return ["tsx", "typescript", "javascript"]
        case "jsx":
            return ["jsx", "javascript"]
        case "yml":
            return ["yaml"]
        case "dockerfile":
            return ["dockerfile", "plaintext"]
        case "":
            return ["plaintext", "ini", "yaml"]
        default:
            return [ext]
        }
    }
}

#Preview("Markdown 内容") {
    FileContentSectionView(content: .constant("# Hello World\n\n这是一段 **Markdown** 内容。"), fileExtension: "md", fileName: "README.md", theme: .default)
        .frame(width: 300, height: 200)
        .padding()
}

#Preview("代码内容") {
    FileContentSectionView(content: .constant("func hello() {\n    print(\"Hello World\")\n}"), fileExtension: "swift", fileName: "main.swift", theme: .ocean)
        .frame(width: 300, height: 200)
        .padding()
}

#Preview("Git 配置") {
    FileContentSectionView(content: .constant("*.pyc\n.DS_Store\n"), fileExtension: "", fileName: ".gitignore", theme: .agate)
        .frame(width: 300, height: 200)
        .padding()
}
