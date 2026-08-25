import Foundation
import PDFKit
import Testing
@testable import KitResume

@Suite("KitResume")
struct KitResumeTests {

    // MARK: - Models

    @Test func paperPresetsMapCssPixelsToPdfPoints() {
        let a4 = ResumePaperSpec.preset(for: .a4)
        #expect(a4.cssWidth == 794 && a4.cssHeight == 1123)
        #expect(abs(a4.pdfWidth - 595.5) < 0.01)
        #expect(abs(a4.pdfHeight - 842.25) < 0.01)

        let letter = ResumePaperSpec.preset(for: .letter)
        #expect(letter.cssWidth == 816 && letter.cssHeight == 1056)
        #expect(abs(letter.pdfWidth - 612) < 0.01)
        #expect(abs(letter.pdfHeight - 792) < 0.01)
    }

    @Test func pixelSizeScalesWithDpi() {
        let a4 = ResumePaperSpec.preset(for: .a4)
        let printPixels = a4.pixelSize(dpi: 300)
        #expect(Int(printPixels.width) == 2481)
        #expect(Int(printPixels.height) == 3509)
        let screenPixels = a4.pixelSize(dpi: 96)
        #expect(Int(screenPixels.width) == 794)
        #expect(Int(screenPixels.height) == 1123)
    }

    // MARK: - Linter

    @Test func builtInTemplatesPassLintForEveryPaperAndTemplate() throws {
        let linter = ResumeHTMLLinter()
        for paper in ResumePaperKind.allCases {
            for template in ResumeTemplateKind.allCases {
                let html = ResumeTemplateFactory.html(title: "Ada Lovelace", template: template, paper: paper)
                let report = linter.lint(html: html, paper: paper)
                #expect(report.isValid, "template \(template) on \(paper) failed: \(report.errors.map(\.message))")
            }
        }
    }

    @Test func linterRejectsScriptsAndRemoteResources() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>.resume-page { width: 794px; height: 1123px; overflow: hidden; background: #fff; }</style>
        </head><body><section class="resume-page"><script src="https://evil.example/x.js"></script></section></body></html>
        """
        let report = linter.lint(html: html)
        let codes = Set(report.errors.map(\.code))
        #expect(codes.contains("script_forbidden"))
        #expect(codes.contains("remote_resource"))
    }

    @Test func linterRejectsMissingResumePage() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>body { margin: 0; }</style>
        </head><body><section class="some-page"></section></body></html>
        """
        let report = linter.lint(html: html)
        #expect(report.errors.contains { $0.code == "missing_resume_page" })
        #expect(report.errors.contains { $0.code == "resume_page_missing_size" })
    }

    @Test func linterRejectsUnsafeAssetPaths() {
        let linter = ResumeHTMLLinter()
        let html = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>.resume-page { width: 794px; height: 1123px; overflow: hidden; background: #fff; }</style>
        </head><body><section class="resume-page"><img src="../../escape.png"></section></body></html>
        """
        let report = linter.lint(html: html)
        #expect(report.errors.contains { $0.code == "unsafe_asset_path" })
    }

    // MARK: - DocumentStore

    @Test func storeCreateReadPatchRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("resumekit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ResumeDocumentStore()

        let created = try store.createResume(
            storagePath: root.path,
            slug: "my-resume",
            title: "My Resume",
            paper: .a4,
            template: .classic
        )
        #expect(created.document.id == "my-resume")
        #expect(created.document.paper == .a4)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("resumes/my-resume/index.html").path))

        let list = try store.listResumes(storagePath: root.path)
        #expect(list.count == 1)
        #expect(list[0].id == "my-resume")

        let read = try store.readResume(storagePath: root.path, slug: "my-resume")
        #expect(read.html == created.html)

        let patched = try store.patchHTML(
            operations: [.init(oldText: "<h1>My Resume</h1>", newText: "<h1>Ada Lovelace</h1>")],
            storagePath: root.path,
            slug: "my-resume"
        )
        #expect(patched.html.contains("Ada Lovelace"))
        #expect(!patched.html.contains("<h1>My Resume</h1>"))

        // 唯一性校验：重复文本无法 patch。
        #expect(throws: ResumeStoreError.patchTextNotUnique("div")) {
            _ = try store.patchHTML(
                operations: [.init(oldText: "div", newText: "span")],
                storagePath: root.path,
                slug: "my-resume"
            )
        }

        try store.deleteResume(storagePath: root.path, slug: "my-resume")
        #expect(try store.listResumes(storagePath: root.path).isEmpty)
    }

    @Test func storeRejectsInvalidSlugAndDuplicates() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("resumekit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ResumeDocumentStore()

        #expect(throws: ResumeStoreError.invalidSlug("My Resume")) {
            _ = try store.createResume(storagePath: root.path, slug: "My Resume", title: "x", paper: .a4, template: .blank)
        }
        _ = try store.createResume(storagePath: root.path, slug: "dup", title: "x", paper: .a4, template: .blank)
        do {
            _ = try store.createResume(storagePath: root.path, slug: "dup", title: "x", paper: .a4, template: .blank)
            Issue.record("expected alreadyExists error")
        } catch let error as ResumeStoreError {
            guard case .alreadyExists = error else {
                Issue.record("unexpected error: \(error)")
                return
            }
        }
    }

    // MARK: - Exporter（需要 WKWebView 运行时，标记为逐条运行）

    @Suite(.serialized)
    struct ExporterTests {
        @Test func exportPDFProducesExactPaperSizedVectorPages() async throws {
            let html = ResumeTemplateFactory.html(title: "Ada Lovelace", template: .classic, paper: .a4)
            let data = try await ResumeHTMLExporter.exportPDF(html: html, fileURL: nil, paper: .a4)
            let document = try #require(PDFDocument(data: data))
            #expect(document.pageCount == 1)
            let page = try #require(document.page(at: 0))
            let bounds = page.bounds(for: .mediaBox)
            let preset = ResumePaperSpec.preset(for: .a4)
            #expect(abs(bounds.width - preset.pdfWidth) < 0.5)
            #expect(abs(bounds.height - preset.pdfHeight) < 0.5)
            // 矢量输出应可提取文本（文字可选中）。
            #expect((page.string ?? "").uppercased().contains("COMPUTER SCIENCE"))
        }

        @Test func exportPNGMatchesDpiPixelSize() async throws {
            let html = ResumeTemplateFactory.html(title: "Ada Lovelace", template: .minimal, paper: .letter)
            let data = try await ResumeHTMLExporter.exportPNG(
                html: html,
                fileURL: nil,
                paper: .letter,
                pageIndex: 0,
                dpi: ResumeExportResolution.print.rawValue
            )
            #expect(data.count > 10_000)
            let image = try #require(NSBitmapImageRep(data: data))
            let preset = ResumePaperSpec.preset(for: .letter)
            let expected = preset.pixelSize(dpi: 300)
            #expect(abs(image.pixelsWide - Int(expected.width)) <= 1)
            #expect(abs(image.pixelsHigh - Int(expected.height)) <= 1)
        }

        @Test func overflowingPageIsReported() async throws {
            let preset = ResumePaperSpec.preset(for: .a4)
            let html = """
            <!doctype html><html lang="en"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              * { box-sizing: border-box; }
              body { margin: 0; }
              .resume-page { width: \(preset.cssWidth)px; height: \(preset.cssHeight)px; overflow: hidden; background: #fff; }
            </style>
            </head><body>
              <section class="resume-page" data-page="1">
                <div style="height: 4000px;">tall content</div>
              </section>
            </body></html>
            """
            let inspection = try await ResumeHTMLExporter.inspectPages(html: html, fileURL: nil, paper: .a4)
            #expect(inspection.pageCount == 1)
            #expect(inspection.overflowingPages == [0])

            await #expect(throws: ResumeExportError.pageOverflow(pages: [1])) {
                _ = try await ResumeHTMLExporter.exportPDF(html: html, fileURL: nil, paper: .a4)
            }
        }

        @Test func wrongPageSizeIsRejectedOnExport() async throws {
            let html = """
            <!doctype html><html lang="en"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              * { box-sizing: border-box; }
              body { margin: 0; }
              .resume-page { width: 700px; height: 900px; overflow: hidden; background: #fff; }
            </style>
            </head><body>
              <section class="resume-page" data-page="1">content</section>
            </body></html>
            """
            await #expect(throws: ResumeExportError.self) {
                _ = try await ResumeHTMLExporter.exportPDF(html: html, fileURL: nil, paper: .a4)
            }
        }
    }
}
