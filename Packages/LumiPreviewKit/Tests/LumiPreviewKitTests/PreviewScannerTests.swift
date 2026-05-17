import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("PreviewScanner")
struct PreviewScannerTests {

    // MARK: - 基本检测

    @Test("单个 #Preview 能被检测到，返回正确的 title、lineNumber、endLineNumber")
    func scanSinglePreview() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        import SwiftUI

        struct MyView: View {
            var body: some View {
                Text("Hello")
            }
        }

        #Preview {
            MyView()
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/MyView.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Preview 1")
        #expect(results[0].lineNumber == 9)
        #expect(results[0].endLineNumber == 11)
        #expect(results[0].sourceFileURL.lastPathComponent == "MyView.swift")
    }

    @Test("无 #Preview 的源码返回空数组")
    func scanNoPreview() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = "import SwiftUI\nstruct MyView: View { var body: some View { Text(\"Hi\") } }"
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/MyView.swift"),
            sourceText: source
        )
        #expect(results.isEmpty)
    }

    // MARK: - 多个 #Preview

    @Test("多个 #Preview 全部被检测到")
    func scanMultiplePreviews() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview("Dirty") {
            GitBranchDetailView(branchName: "main", isDirty: true)
        }

        #Preview("Clean") {
            GitBranchDetailView(branchName: "release/1.4", isDirty: false)
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/GitBranchDetailView.swift"),
            sourceText: source
        )
        #expect(results.count == 2)
        #expect(results[0].title == "Dirty")
        #expect(results[0].lineNumber == 1)
        #expect(results[0].endLineNumber == 3)
        #expect(results[1].title == "Clean")
        #expect(results[1].lineNumber == 5)
        #expect(results[1].endLineNumber == 7)
    }

    // MARK: - Title 提取

    @Test("#Preview(\"Title\") 的 title 被正确提取")
    func scanExtractsTitle() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview("Detail View") {
            GitBranchDetailView(branchName: "main", isDirty: true)
                .frame(width: 300)
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/GitBranchDetailView.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Detail View")
    }

    @Test("多行签名的 title 被正确提取")
    func scanExtractsMultilineTitle() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview(
            "Multiline Title"
        ) {
            GitBranchDetailView(branchName: "main", isDirty: true)
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/GitBranchDetailView.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Multiline Title")
        #expect(results[0].lineNumber == 1)
        #expect(results[0].endLineNumber == 5)
    }

    @Test("无标题的 #Preview 获得默认序号标题")
    func scanUntitledPreview() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview {
            EmptyView()
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/EmptyPreview.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Preview 1")
    }

    // MARK: - 注释和字符串跳过

    @Test("单行注释中的 #Preview 不被误检")
    func scanIgnoresLineComment() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        // #Preview("Ignored") { EmptyView() }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
            sourceText: source
        )
        #expect(results.isEmpty)
    }

    @Test("多行注释中的 #Preview 不被误检")
    func scanIgnoresBlockComment() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        /*
        #Preview("Ignored Block Comment") {
            EmptyView()
        }
        */
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
            sourceText: source
        )
        #expect(results.isEmpty)
    }

    @Test("字符串中的 #Preview 不被误检")
    func scanIgnoresStringLiteral() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        let marker = "#Preview(\"Ignored String\") { EmptyView() }"
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
            sourceText: source
        )
        #expect(results.isEmpty)
    }

    @Test("多行字符串中的 #Preview 不被误检")
    func scanIgnoresMultilineStringLiteral() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = #"""
        let multiline = """
        #Preview("Ignored Multiline String") {
            EmptyView()
        }
        """

        #Preview("Real") {
            VStack {
                Text("}")
            }
        }
        """#
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Real")
    }

    @Test("注释和字符串混合场景下只检测真正的 #Preview")
    func scanIgnoresAllCommentAndStringMarkers() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = #"""
        // #Preview("Ignored Line Comment") { EmptyView() }
        let marker = "#Preview(\"Ignored String\") { EmptyView() }"
        /*
        #Preview("Ignored Block Comment") {
            EmptyView()
        }
        */
        let multiline = """
        #Preview("Ignored Multiline String") {
            EmptyView()
        }
        """

        #Preview("Real") {
            VStack {
                Text("}")
            }
        }
        """#
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/CommentedPreview.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Real")
        #expect(results[0].lineNumber == 14)
        #expect(results[0].endLineNumber == 18)
    }

    // MARK: - 花括号平衡

    @Test("嵌套花括号正确匹配，endLineNumber 准确")
    func scanBalancedBraces() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview {
            VStack {
                HStack {
                    Text("Hello")
                }
            }
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].lineNumber == 1)
        #expect(results[0].endLineNumber == 7)
    }

    // MARK: - primaryTypeName 提取

    @Test("primaryTypeName 被正确提取（如 MyView）")
    func scanExtractsPrimaryTypeName() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview("Detail View") {
            GitBranchDetailView(branchName: "main", isDirty: true)
                .frame(width: 300)
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/GitBranchDetailView.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].primaryTypeName == "GitBranchDetailView")
    }

    @Test("以点开头的闭包体不提取 primaryTypeName")
    func scanPrimaryTypeNameDotPrefix() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview {
            .someView
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].primaryTypeName == nil)
    }

    // MARK: - bodySource 提取

    @Test("bodySource 闭包体被正确提取")
    func scanExtractsBodySource() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview("Detail View") {
            GitBranchDetailView(branchName: "main", isDirty: true)
                .frame(width: 300)
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/GitBranchDetailView.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        let body = results[0].bodySource
        #expect(body != nil)
        #expect(body?.contains("GitBranchDetailView(branchName: \"main\", isDirty: true)") == true)
        #expect(body?.contains(".frame(width: 300)") == true)
    }

    // MARK: - id 稳定性

    @Test("id 包含行号和序号信息")
    func scanStableId() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview {
            EmptyView()
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].id == "source-preview-1-0")
    }

    @Test("5.1 detects preview with traits in signature")
    func scanPreviewWithTraits() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        import SwiftUI

        #Preview("Sized", traits: .sizeThatFitsLayout) {
            Text("Hello")
        }
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/TraitsPreview.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Sized")
        #expect(results[0].bodySource?.contains("Text(\"Hello\")") == true)
    }

    @Test("5.2 unclosed brace does not crash scanner")
    func scanUnclosedBraceDoesNotCrash() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        #Preview("Broken") {
            Text("Hello")
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/BrokenPreview.swift"),
            sourceText: source
        )
        #expect(results.isEmpty)
    }

    @Test("5.3 detects preview inside DEBUG conditional compilation")
    func scanPreviewInsideIfDebug() {
        let scanner = LumiPreviewFacade.PreviewScanner()
        let source = """
        import SwiftUI

        #if DEBUG
        #Preview("Debug Only") {
            Text("Debug")
        }
        #endif
        """
        let results = scanner.scan(
            fileURL: URL(fileURLWithPath: "/tmp/DebugPreview.swift"),
            sourceText: source
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Debug Only")
    }
}
