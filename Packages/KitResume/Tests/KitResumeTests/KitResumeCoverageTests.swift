import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Testing

@testable import KitResume

// MARK: - Helpers

/// 生成一张指定尺寸的真实 PNG，用于驱动 ImageIO 解析。
private func writePNG(width: Int, height: Int, to url: URL) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

/// 创建一次性临时目录，测试结束自动清理。
private func makeTemporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("resumekit-cov-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

/// 通过全部静态校验的最小 HTML 骨架。
private func validResumeHTML(pageBody: String = "<p>content</p>") -> String {
    """
    <!doctype html><html lang="en"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      body { margin: 0; }
      .resume-page { width: 794px; height: 1123px; overflow: hidden; background: #fff; }
      .entry { break-inside: avoid; }
    </style>
    </head><body><section class="resume-page">\(pageBody)</section></body></html>
    """
}

// MARK: - Asset importer

@Suite("ResumeAssetImporter")
struct ResumeAssetImporterTests {

    @Test("源文件不存在时抛出 sourceNotFound")
    func throwsWhenSourceIsMissing() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = root.appendingPathComponent("nope.png")
        let importer = ResumeAssetImporter()

        #expect(throws: ResumeAssetError.sourceNotFound(missing.path)) {
            _ = try importer.importImage(sourceURL: missing, destinationDirectory: root)
        }
    }

    @Test("超过 50MB 上限时抛出 fileTooLarge")
    func throwsWhenFileIsTooLarge() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let big = root.appendingPathComponent("big.png")
        FileManager.default.createFile(atPath: big.path, contents: Data())
        let handle = try FileHandle(forWritingTo: big)
        try handle.truncate(atOffset: UInt64(50 * 1024 * 1024 + 1))
        try handle.close()
        defer { try? FileManager.default.removeItem(at: big) }

        let importer = ResumeAssetImporter()
        #expect(throws: ResumeAssetError.fileTooLarge(50 * 1024 * 1024 + 1)) {
            _ = try importer.importImage(sourceURL: big, destinationDirectory: root)
        }
    }

    @Test("非图片文件抛出 unsupportedImage")
    func throwsForUnsupportedImage() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let text = root.appendingPathComponent("notes.txt")
        try "hello".write(to: text, atomically: true, encoding: .utf8)

        let importer = ResumeAssetImporter()
        #expect(throws: ResumeAssetError.unsupportedImage(text.path)) {
            _ = try importer.importImage(sourceURL: text, destinationDirectory: root)
        }
    }

    @Test("导入图片后返回相对路径与像素尺寸，并在目标目录创建副本")
    func importsImageSuccessfully() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("photo.png")
        try writePNG(width: 12, height: 7, to: source)

        let destination = root.appendingPathComponent("nested/assets", isDirectory: true)
        let importer = ResumeAssetImporter()
        let asset = try importer.importImage(sourceURL: source, destinationDirectory: destination)

        #expect(asset.pixelWidth == 12)
        #expect(asset.pixelHeight == 7)
        #expect(asset.relativePath == "./assets/photo.png")
        #expect(asset.fileURL.lastPathComponent == "photo.png")
        #expect(FileManager.default.fileExists(atPath: asset.fileURL.path))
        #expect(FileManager.default.fileExists(atPath: destination.path))
    }

    @Test("指定文件名时按规则净化，非法字符替换为连字符")
    func sanitizesPreferredFileName() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("photo.png")
        try writePNG(width: 4, height: 4, to: source)

        let destination = root.appendingPathComponent("assets", isDirectory: true)
        let importer = ResumeAssetImporter()
        let asset = try importer.importImage(
            sourceURL: source,
            destinationDirectory: destination,
            preferredFileName: "my photo (v2).png"
        )

        #expect(asset.fileURL.lastPathComponent == "my-photo-v2-.png")
        #expect(asset.relativePath == "./assets/my-photo-v2-.png")
    }

    @Test("文件名净化后只剩非法字符时替换为连字符")
    func replacesFullyIllegalFileName() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("photo.png")
        try writePNG(width: 3, height: 3, to: source)

        let destination = root.appendingPathComponent("assets", isDirectory: true)
        let importer = ResumeAssetImporter()
        let asset = try importer.importImage(
            sourceURL: source,
            destinationDirectory: destination,
            preferredFileName: "///"
        )

        // `safeFileName` 的 "asset.png" 兜底分支在 macOS 上不可达：
        // `URL(fileURLWithPath:)` 解析出的 lastPathComponent 永远非空。
        #expect(asset.fileURL.lastPathComponent == "-")
    }

    @Test("目标文件已存在时自动追加序号避免覆盖")
    func avoidsOverwritingExistingFile() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("photo.png")
        try writePNG(width: 2, height: 2, to: source)

        let destination = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try "old".write(to: destination.appendingPathComponent("photo.png"), atomically: true, encoding: .utf8)

        let importer = ResumeAssetImporter()
        let asset = try importer.importImage(sourceURL: source, destinationDirectory: destination)

        #expect(asset.fileURL.lastPathComponent == "photo-2.png")
        #expect(asset.relativePath == "./assets/photo-2.png")
        // 原有文件未被覆盖。
        let previous = try String(contentsOf: destination.appendingPathComponent("photo.png"), encoding: .utf8)
        #expect(previous == "old")
    }

    @Test("ResumeAssetError 的错误描述覆盖全部 case")
    func assetErrorDescriptions() {
        #expect(ResumeAssetError.sourceNotFound("/a/b.png").errorDescription == "Asset does not exist: /a/b.png")
        #expect(ResumeAssetError.unsupportedImage("/a/b.png").errorDescription == "Asset is not a supported image: /a/b.png")
        #expect(
            ResumeAssetError.fileTooLarge(1024).errorDescription
                == "Asset exceeds the 50 MB limit (1024 bytes)."
        )
    }

    @Test("ResumeImportedAsset 保持值语义")
    func importedAssetIsEquatable() throws {
        let url = URL(fileURLWithPath: "/tmp/photo.png")
        let asset = ResumeImportedAsset(fileURL: url, relativePath: "./assets/photo.png", pixelWidth: 2, pixelHeight: 3)
        let same = ResumeImportedAsset(fileURL: url, relativePath: "./assets/photo.png", pixelWidth: 2, pixelHeight: 3)
        #expect(asset == same)
        #expect(asset != ResumeImportedAsset(fileURL: url, relativePath: "./assets/x.png", pixelWidth: 2, pixelHeight: 3))
    }
}

// MARK: - Models

@Suite("Resume models")
struct ResumeModelTests {

    @Test("纸张枚举暴露 id 与展示名")
    func paperKindMetadata() {
        #expect(ResumePaperKind.allCases == [.a4, .letter])
        #expect(ResumePaperKind.a4.id == "a4")
        #expect(ResumePaperKind.a4.displayName == "A4 (210 × 297 mm)")
        #expect(ResumePaperKind.letter.displayName == "US Letter (8.5 × 11 in)")
    }

    @Test("纸张预设派生 CSS 尺寸、PDF 点尺寸与 DPI 像素尺寸")
    func paperPresetDerivedSizes() {
        let a4 = ResumePaperSpec.preset(for: .a4)
        #expect(a4.id == "a4")
        #expect(a4.cgSize == CGSize(width: 794, height: 1123))
        #expect(abs(a4.pdfSize.width - 595.5) < 0.01)
        #expect(abs(a4.pdfSize.height - 842.25) < 0.01)

        let letter = ResumePaperSpec.preset(for: .letter)
        #expect(letter.cgSize == CGSize(width: 816, height: 1056))

        let high = a4.pixelSize(dpi: 150)
        #expect(abs(high.width - 1240.6) < 0.5)
        #expect(abs(high.height - 1754.7) < 0.5)
    }

    @Test("模板枚举暴露 id 与展示名")
    func templateKindMetadata() {
        #expect(ResumeTemplateKind.allCases == [.classic, .modern, .minimal, .blank])
        #expect(ResumeTemplateKind.classic.id == "classic")
        #expect(ResumeTemplateKind.classic.displayName == "Classic (single column, ATS-friendly)")
        #expect(ResumeTemplateKind.modern.displayName == "Modern (two columns with accent sidebar)")
        #expect(ResumeTemplateKind.minimal.displayName == "Minimal (single column, generous spacing)")
        #expect(ResumeTemplateKind.blank.displayName == "Blank (start from scratch)")
    }

    @Test("导出分辨率枚举暴露 id、原始值与展示名")
    func exportResolutionMetadata() {
        #expect(ResumeExportResolution.allCases == [.screen, .high, .print])
        #expect(ResumeExportResolution.screen.rawValue == 96)
        #expect(ResumeExportResolution.high.rawValue == 150)
        #expect(ResumeExportResolution.print.rawValue == 300)
        #expect(ResumeExportResolution.screen.id == 96)
        #expect(ResumeExportResolution.screen.displayName == "96 dpi (screen)")
        #expect(ResumeExportResolution.high.displayName == "150 dpi (high)")
        #expect(ResumeExportResolution.print.displayName == "300 dpi (print)")
    }

    @Test("简历文档可编码解码往返")
    func documentCodableRoundTrip() throws {
        let document = ResumeDocument(
            id: "ada",
            title: "Ada Lovelace",
            paper: .letter,
            template: .modern,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        #expect(ResumeDocument.currentSchemaVersion == 1)
        #expect(document.schemaVersion == 1)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(document)
        let decoded = try decoder.decode(ResumeDocument.self, from: data)
        #expect(decoded == document)
    }

    @Test("已解析文档推导 HTML 与资产目录地址")
    func resolvedDocumentDerivedURLs() {
        let directory = URL(fileURLWithPath: "/tmp/resumes/ada", isDirectory: true)
        let document = ResumeDocument(id: "ada", title: "Ada", paper: .a4, template: .classic)

        let implicit = ResumeResolvedDocument(document: document, directoryURL: directory, html: "<html></html>")
        #expect(implicit.htmlURL.lastPathComponent == "index.html")
        #expect(implicit.assetsDirectoryURL.lastPathComponent == "assets")
        #expect(implicit.assetsDirectoryURL.deletingLastPathComponent().lastPathComponent == "ada")

        let explicit = ResumeResolvedDocument(
            document: document,
            directoryURL: directory,
            html: "<html></html>",
            htmlURL: directory.appendingPathComponent("custom.html")
        )
        #expect(explicit.htmlURL.lastPathComponent == "custom.html")
    }
}

// MARK: - Linter

@Suite("ResumeHTMLLinter")
struct ResumeHTMLLinterTests {

    @Test("报告把问题按严重级别分流")
    func reportSplitsErrorsAndWarnings() {
        let report = ResumeLintReport(issues: [
            .init(severity: .error, code: "e", message: "boom"),
            .init(severity: .warning, code: "w", message: "careful"),
        ])
        #expect(report.errors.count == 1)
        #expect(report.warnings.count == 1)
        #expect(report.errors.first?.code == "e")
        #expect(report.warnings.first?.code == "w")
        #expect(report.isValid == false)
        #expect(ResumeLintReport(issues: []).isValid)
    }

    @Test("超出字节上限时报 html_too_large")
    func rejectsOversizedHTML() {
        let linter = ResumeHTMLLinter(maximumUTF8Bytes: 128)
        let html = validResumeHTML(pageBody: String(repeating: "x", count: 512))
        let report = linter.lint(html: html)
        #expect(report.errors.contains { $0.code == "html_too_large" })
    }

    @Test("缺少 doctype 或 html 标签时报 incomplete_document")
    func rejectsIncompleteDocument() {
        let linter = ResumeHTMLLinter()
        let report = linter.lint(html: "<div>only a fragment</div>")
        #expect(report.errors.contains { $0.code == "incomplete_document" })
    }

    @Test("缺少 viewport 元标签时报 missing_viewport")
    func rejectsMissingViewport() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8"></head>
        <body><section class="resume-page">x</section></body></html>
        """
        let report = linter.lint(html: html)
        #expect(report.errors.contains { $0.code == "missing_viewport" })
    }

    @Test("出现 iframe 时报 iframe_forbidden")
    func rejectsIframe() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body><section class="resume-page"><iframe src="about:blank"></iframe></section></body></html>
        """
        let report = linter.lint(html: html)
        #expect(report.errors.contains { $0.code == "iframe_forbidden" })
    }

    @Test("出现 CSS @import 时报 css_import_forbidden")
    func rejectsCSSImport() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>@import url("other.css");</style></head>
        <body><section class="resume-page">x</section></body></html>
        """
        let report = linter.lint(html: html)
        #expect(report.errors.contains { $0.code == "css_import_forbidden" })
    }

    @Test("出现动画或过渡时给出 motion_disabled 警告")
    func warnsAboutMotion() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>.resume-page { width: 794px; height: 1123px; overflow: hidden; background: #fff; animation: spin 1s; }</style>
        </head><body><section class="resume-page">x</section></body></html>
        """
        let report = linter.lint(html: html)
        #expect(report.warnings.contains { $0.code == "motion_disabled" })
    }

    @Test(".resume-page 规则缺少宽高时报 resume_page_missing_size")
    func rejectsPageWithoutSize() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>.resume-page { color: #000; }</style>
        </head><body><section class="resume-page">x</section></body></html>
        """
        let report = linter.lint(html: html)
        #expect(report.errors.contains { $0.code == "resume_page_missing_size" })
    }

    @Test("完全没有 .resume-page CSS 规则时同样报 resume_page_missing_size")
    func rejectsMissingPageRule() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body><section class="resume-page">x</section></body></html>
        """
        let report = linter.lint(html: html)
        #expect(report.errors.contains { $0.code == "resume_page_missing_size" })
    }

    @Test("引用不存在的本地资产时报 missing_asset")
    func reportsMissingAsset() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>.resume-page { width: 794px; height: 1123px; overflow: hidden; background: #fff; }</style>
        </head><body><section class="resume-page"><img src="assets/photo.png"></section></body></html>
        """
        let report = linter.lint(html: html, paper: .a4, documentDirectory: root)
        #expect(report.errors.contains { $0.code == "missing_asset" })
    }

    @Test("合法模板不产生任何错误")
    func acceptsValidHTML() {
        let linter = ResumeHTMLLinter()
        let report = linter.lint(html: validResumeHTML(), paper: .a4)
        #expect(report.isValid, "unexpected errors: \(report.errors.map(\.message))")
    }
}

// MARK: - Document store

@Suite("ResumeDocumentStore")
struct ResumeDocumentStoreTests {

    @Test("create/list/read/lint/assets/delete 全链路")
    func fullLifecycle() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ResumeDocumentStore()
        let created = try store.createResume(
            storagePath: root.path,
            slug: "ada",
            title: "Ada Lovelace",
            paper: .a4,
            template: .classic
        )
        #expect(created.document.title == "Ada Lovelace")
        #expect(created.document.template == .classic)

        let listed = try store.listResumes(storagePath: root.path)
        #expect(listed.map(\.id) == ["ada"])

        let linted = try store.lintResume(storagePath: root.path, slug: "ada")
        #expect(linted.isValid, "unexpected errors: \(linted.errors.map(\.message))")

        let assets = try store.assetsDirectoryURL(storagePath: root.path, slug: "ada")
        #expect(FileManager.default.fileExists(atPath: assets.path))
        #expect(assets.lastPathComponent == "assets")

        try store.deleteResume(storagePath: root.path, slug: "ada")
        #expect(try store.listResumes(storagePath: root.path).isEmpty)
    }

    @Test("删除不存在的简历抛出 notFound")
    func throwsWhenDeletingMissingResume() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ResumeDocumentStore()
        #expect(throws: ResumeStoreError.self) {
            try store.deleteResume(storagePath: root.path, slug: "ghost")
        }
    }

    @Test("空标题回退到 slug")
    func fallsBackToSlugForEmptyTitle() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ResumeDocumentStore()
        let created = try store.createResume(
            storagePath: root.path,
            slug: "untitled",
            title: "",
            paper: .a4,
            template: .blank
        )
        #expect(created.document.title == "untitled")
    }

    @Test("路径白名单判定覆盖相等、前缀与越界三种情况")
    func pathAllowListChecks() {
        let allowed = "/tmp/allowed"
        #expect(ResumeDocumentStore.isPathAllowed("/tmp/allowed/child/file.png", allowedDirectories: [allowed]))
        #expect(ResumeDocumentStore.isPathAllowed("/tmp/allowed", allowedDirectories: [allowed]))
        #expect(!ResumeDocumentStore.isPathAllowed("/tmp/other/file.png", allowedDirectories: [allowed]))
        // 白名单为空时不做限制。
        #expect(ResumeDocumentStore.isPathAllowed("/anywhere/file.png", allowedDirectories: []))
    }

    @Test("slug 校验会修剪空白并转小写")
    func validatedSlugNormalizes() throws {
        #expect(try ResumeDocumentStore.validatedSlug("  Ada-Resume  ") == "ada-resume")
        #expect(throws: ResumeStoreError.invalidSlug("Ada Resume")) {
            _ = try ResumeDocumentStore.validatedSlug("Ada Resume")
        }
        #expect(throws: ResumeStoreError.invalidSlug("")) {
            _ = try ResumeDocumentStore.validatedSlug("")
        }
    }

    @Test("ResumeStoreError 的错误描述覆盖全部 case")
    func storeErrorDescriptions() {
        #expect(
            ResumeStoreError.invalidStoragePath.errorDescription
                == "Plugin storage path is missing or invalid."
        )
        #expect(ResumeStoreError.invalidSlug("x y").errorDescription == "Invalid slug: x y")
        #expect(ResumeStoreError.alreadyExists("/a").errorDescription == "Item already exists at /a")
        #expect(ResumeStoreError.notFound("/a").errorDescription == "Resume not found at /a")
        #expect(ResumeStoreError.patchTextMissing("abc").errorDescription == "Patch text was not found: abc")
        #expect(
            ResumeStoreError.patchTextNotUnique("abc").errorDescription
                == "Patch text must occur exactly once: abc"
        )
        #expect(
            ResumeStoreError.pathNotAllowed("/a").errorDescription
                == "Path is outside the allowed directories: /a"
        )
        let issue = ResumeLintIssue(severity: .error, code: "c", message: "bad html")
        let htmlError = ResumeStoreError.invalidHTML([issue])
        #expect(htmlError.errorDescription == "HTML validation failed: bad html")
    }
}

// MARK: - Export errors

@Suite("ResumeExportError")
struct ResumeExportErrorTests {

    @Test("错误描述覆盖全部 case")
    func exportErrorDescriptions() {
        #expect(ResumeExportError.loadTimedOut.errorDescription == "Timed out while loading resume HTML.")
        #expect(
            ResumeExportError.resourcesTimedOut.errorDescription
                == "Timed out while waiting for images and fonts."
        )
        #expect(ResumeExportError.noPages.errorDescription == "HTML contains no .resume-page elements.")
        #expect(
            ResumeExportError.unexpectedPageSize(
                page: 2,
                expectedWidth: 794,
                expectedHeight: 1123,
                actualWidth: 700,
                actualHeight: 900
            ).errorDescription
                == "Page 2 renders at 700.0x900.0 but the paper preset requires 794.0x1123.0."
        )
        #expect(
            ResumeExportError.pageOverflow(pages: [1, 3]).errorDescription
                == "Content overflows .resume-page container(s): 2, 4. Reduce content or add another page."
        )
        #expect(ResumeExportError.pdfCreationFailed.errorDescription == "Failed to create PDF from resume HTML.")
        #expect(ResumeExportError.pngEncodingFailed.errorDescription == "Failed to encode resume PNG.")
    }

    @Test("页面检查结果汇总页数与溢出页")
    func inspectionSummarizesPages() {
        let pages = [
            ResumePageInspection.Page(index: 0, top: 0, left: 0, width: 794, height: 1123, isOverflowing: false),
            ResumePageInspection.Page(index: 1, top: 1123, left: 0, width: 794, height: 1123, isOverflowing: true),
        ]
        let inspection = ResumePageInspection(pages: pages)
        #expect(inspection.pageCount == 2)
        #expect(inspection.overflowingPages == [1])
    }
}
