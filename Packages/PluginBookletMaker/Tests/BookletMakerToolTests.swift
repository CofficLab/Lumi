import CoreGraphics
import Foundation
import KitAgentTool
import PDFKit
import ProviderSkill
import Testing
@testable import BookletMakerPlugin

// MARK: - Booklet Maker Agent Tools

/// 覆盖 BookletMaker 贡献的 Agent 工具：工具名集合、真实拼版/拆分落盘、
/// 参数校验与 Skill 元数据解析。
///
/// 注意：工具结果的**错误文案随宿主语言变化**（`BookletToolSupport.language`
/// 跟随系统 locale），因此断言统一走 `either(_:_:_:)`，只校验语言无关的部分。
@Suite("Booklet maker agent tools")
struct BookletMakerToolTests {

    // MARK: - Tool set

    @Test func contributesCompleteToolSet() {
        let names = Set(BookletMakerPlugin.agentTools.map(\.name))
        #expect(names == [
            "pdf_inspect",
            "booklet_make",
            "pdf_split",
            "booklet_preview",
        ])
    }

    @Test func contributesToolNamesAndRiskLevels() {
        for tool in BookletMakerPlugin.agentTools {
            #expect(!tool.name.isEmpty)
            #expect(!tool.description(for: .english).isEmpty)
            #expect(!tool.displayDescription(for: [:]).isEmpty)
        }
        #expect(PDFInspectTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(BookletPreviewTool().permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test func writeToolsRaiseRiskWhenOverwriting() {
        #expect(BookletMakeTool().permissionRiskLevel(arguments: [:]) == .medium)
        #expect(BookletMakeTool().permissionRiskLevel(
            arguments: ["overwrite": ToolArgument(true)]
        ) == .high)
        #expect(PDFSplitTool().permissionRiskLevel(arguments: [:]) == .medium)
        #expect(PDFSplitTool().permissionRiskLevel(
            arguments: ["overwrite": ToolArgument(true)]
        ) == .high)
    }

    @Test func readOnlyToolsDeclareParallelReadOnly() {
        #expect(PDFInspectTool().executionCapability == .parallelReadOnly)
        #expect(BookletPreviewTool().executionCapability == .parallelReadOnly)
    }

    // MARK: - pdf_inspect

    @Test func inspectReportsPageCountAndPlan() async throws {
        let source = try makeSourcePDF(pageCount: 8)
        defer { try? FileManager.default.removeItem(at: source) }

        let output = try await PDFInspectTool().execute(
            arguments: ["path": ToolArgument(source.path)]
        )

        #expect(output.contains("pages: 8"))
        #expect(output.contains("physical sheets: 2"))
        #expect(output.contains("print sides: 4"))
        // 8 页 bookletFold 的首面映射为 8 | 1。
        #expect(output.contains("Sheet 1 front: 8 | 1"))
    }

    @Test func inspectHonoursLayoutOverride() async throws {
        let source = try makeSourcePDF(pageCount: 6)
        defer { try? FileManager.default.removeItem(at: source) }

        let output = try await PDFInspectTool().execute(arguments: [
            "path": ToolArgument(source.path),
            "layout": ToolArgument("simplePair"),
            "paper": ToolArgument("letter"),
        ])

        #expect(output.contains("simplePair"))
        #expect(output.contains("paper: Letter"))
        // simplePair 保持文档顺序：第 1 面为 1 | 2。
        #expect(output.contains("Sheet 1 front: 1 | 2"))
    }

    @Test func inspectRejectsMissingFile() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("absent-\(UUID().uuidString).pdf")
        let output = try await PDFInspectTool().execute(
            arguments: ["path": ToolArgument(missing.path)]
        )
        #expect(either(output, "Error", "错误"))
        #expect(output.contains(missing.lastPathComponent))
    }

    // MARK: - booklet_make

    @Test func makeWritesImposedBooklet() async throws {
        let source = try makeSourcePDF(pageCount: 6)
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: directory)
        }
        let outputURL = directory.appendingPathComponent("out/booklet.pdf")

        let message = try await BookletMakeTool().execute(arguments: [
            "sourcePath": ToolArgument(source.path),
            "outputPath": ToolArgument(outputURL.path),
        ])

        #expect(message.contains("sourcePages: 6"))
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // 6 页补白到 8 个槽位 → 2 张纸 / 4 个印刷面。
        let output = try #require(PDFDocument(url: outputURL))
        #expect(output.pageCount == 4)
    }

    @Test func makeRefusesToOverwriteByDefault() async throws {
        let source = try makeSourcePDF(pageCount: 4)
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: directory)
        }
        let outputURL = directory.appendingPathComponent("booklet.pdf")
        try Data("existing".utf8).write(to: outputURL)

        let message = try await BookletMakeTool().execute(arguments: [
            "sourcePath": ToolArgument(source.path),
            "outputPath": ToolArgument(outputURL.path),
        ])

        #expect(either(message, "already exists", "已存在"))
        // 必须原封不动保留旧文件。
        let preserved = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(preserved == "existing")
    }

    @Test func makeKeepsExistingFileWhenRenderFails() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 源文件不是合法 PDF → 渲染必然失败。
        let brokenSource = directory.appendingPathComponent("broken.pdf")
        try Data("not a pdf".utf8).write(to: brokenSource)

        let outputURL = directory.appendingPathComponent("booklet.pdf")
        try Data("precious".utf8).write(to: outputURL)

        let message = try await BookletMakeTool().execute(arguments: [
            "sourcePath": ToolArgument(brokenSource.path),
            "outputPath": ToolArgument(outputURL.path),
            "overwrite": ToolArgument(true),
        ])

        #expect(either(message, "Error", "错误"))
        // overwrite=true 时渲染失败也必须保住旧文件，不能先删后写。
        let preserved = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(preserved == "precious")

        // 不得留下临时中间产物。
        let leftovers = try FileManager.default
            .contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix(".booklet-") }
        #expect(leftovers.isEmpty)
    }

    @Test func makeOverwritesWhenExplicitlyAllowed() async throws {
        let source = try makeSourcePDF(pageCount: 4)
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: directory)
        }
        let outputURL = directory.appendingPathComponent("booklet.pdf")
        try Data("stale".utf8).write(to: outputURL)

        _ = try await BookletMakeTool().execute(arguments: [
            "sourcePath": ToolArgument(source.path),
            "outputPath": ToolArgument(outputURL.path),
            "overwrite": ToolArgument(true),
        ])

        // 旧内容必须被真正的 PDF 取代。
        // 4 页源 → 恰好 4 个槽位 → 2 个印刷面（1 张纸的正反面）。
        let output = try #require(PDFDocument(url: outputURL))
        #expect(output.pageCount == 2)
    }

    @Test func makeRejectsNegativeGutter() async throws {
        let source = try makeSourcePDF(pageCount: 4)
        defer { try? FileManager.default.removeItem(at: source) }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-\(UUID().uuidString).pdf")

        let message = try await BookletMakeTool().execute(arguments: [
            "sourcePath": ToolArgument(source.path),
            "outputPath": ToolArgument(outputURL.path),
            "gutterMM": ToolArgument(-5.0),
        ])

        #expect(either(message, "Error", "错误"))
        #expect(!FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - pdf_split

    @Test func splitWritesOnePDFPerRange() async throws {
        let source = try makeSourcePDF(pageCount: 10)
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: directory)
        }
        let outputDirectory = directory.appendingPathComponent("parts", isDirectory: true)

        let message = try await PDFSplitTool().execute(arguments: [
            "sourcePath": ToolArgument(source.path),
            "outputDirectory": ToolArgument(outputDirectory.path),
            "cutPoints": ToolArgument([3, 7]),
        ])

        #expect(message.contains("Split 10 pages into 3 PDF files"))

        let files = try FileManager.default
            .contentsOfDirectory(atPath: outputDirectory.path)
            .sorted()
        #expect(files.count == 3)

        // 切点 3 / 7 → 1–3、4–7、8–10 三段。
        let first = try #require(PDFDocument(url: outputDirectory.appendingPathComponent(files[0])))
        #expect(first.pageCount == 3)
        let middle = try #require(PDFDocument(url: outputDirectory.appendingPathComponent(files[1])))
        #expect(middle.pageCount == 4)
        let last = try #require(PDFDocument(url: outputDirectory.appendingPathComponent(files[2])))
        #expect(last.pageCount == 3)
    }

    @Test func splitAcceptsCommaSeparatedCutPoints() async throws {
        let source = try makeSourcePDF(pageCount: 8)
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: directory)
        }

        // 模型可能把 cutPoints 写成字符串，工具应同样接受。
        let message = try await PDFSplitTool().execute(arguments: [
            "sourcePath": ToolArgument(source.path),
            "outputDirectory": ToolArgument(directory.path),
            "cutPoints": ToolArgument("2, 5"),
        ])

        #expect(message.contains("Split 8 pages into 3 PDF files"))
    }

    @Test func splitRejectsOutOfRangeCutPoint() async throws {
        let source = try makeSourcePDF(pageCount: 5)
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: directory)
        }

        let message = try await PDFSplitTool().execute(arguments: [
            "sourcePath": ToolArgument(source.path),
            "outputDirectory": ToolArgument(directory.path),
            "cutPoints": ToolArgument([9]),
        ])

        #expect(either(message, "Invalid argument", "无效参数"))
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.isEmpty)
    }

    // MARK: - booklet_preview

    @Test func previewAttachesRenderedSides() async throws {
        let source = try makeSourcePDF(pageCount: 8)
        defer { try? FileManager.default.removeItem(at: source) }

        let result = try await BookletPreviewTool().executeResult(arguments: [
            "path": ToolArgument(source.path),
            "maxSides": ToolArgument(2),
            "maxPixelWidth": ToolArgument(200.0),
        ])

        #expect(result.isError == false)
        #expect(result.images.count == 2)
        #expect(result.images.allSatisfy { $0.mimeType == "image/png" })
        #expect(result.images.allSatisfy { !$0.data.isEmpty })
        #expect(result.content.contains("Rendered 2 of 4 print sides"))
    }

    @Test func previewClampsRequestedSidesToAvailable() async throws {
        let source = try makeSourcePDF(pageCount: 4)
        defer { try? FileManager.default.removeItem(at: source) }

        // 4 页 → 补白到 4 槽位 → 2 个印刷面；请求 12 面只应渲染出 2 张。
        let result = try await BookletPreviewTool().executeResult(arguments: [
            "path": ToolArgument(source.path),
            "maxSides": ToolArgument(12),
            "maxPixelWidth": ToolArgument(150.0),
        ])

        #expect(result.isError == false)
        #expect(result.images.count == 2)
        #expect(result.content.contains("Rendered 2 of 2 print sides"))
    }

    // MARK: - Skill

    @Test func skillDirectoryLoadsMetadataAndContent() throws {
        let contributor = BookletMakerSkillContributor()
        #expect(contributor.providerID == BookletMakerPlugin.pluginID)
        #expect(contributor.allSkills.count == 1)

        let skill = try #require(contributor.allSkills.first)
        #expect(skill.name == "booklet-maker")
        #expect(skill.triggers.contains("小册子"))

        let content = try #require(skill.loadContent())
        // SKILL.md 必须覆盖全部工具，避免指南与实现漂移。
        for tool in BookletMakerPlugin.agentTools.map(\.name) {
            #expect(content.contains(tool))
        }
    }

    // MARK: - Helpers

    /// 语言无关断言：命中任一候选文案即可。
    private func either(_ text: String, _ english: String, _ chinese: String) -> Bool {
        text.contains(english) || text.contains(chinese)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-tool-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 生成一份最小的 A4 源 PDF。
    private func makeSourcePDF(pageCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-tool-source-\(UUID().uuidString).pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw BookletToolTestError.cannotBuildPDF
        }
        for _ in 0..<pageCount {
            ctx.beginPDFPage(nil)
            ctx.setFillColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
            ctx.fill(mediaBox)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        try (data as Data).write(to: url, options: .atomic)
        return url
    }

    private enum BookletToolTestError: Error {
        case cannotBuildPDF
    }
}
