import Foundation
import KitResume
import Testing

/// KitResume 存储层测试：验证 ResumeDocumentStore 的 CRUD、校验与补丁语义。
@Suite("KitResume ResumeDocumentStore")
struct ResumeDocumentStoreTests {
    private func makeStorage() -> (store: ResumeDocumentStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResumeDocumentStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (ResumeDocumentStore(), directory)
    }

    /// 构造能通过静态 lint 的最小完整 HTML（.resume-page 尺寸匹配纸张预设）。
    private func validHTML(title: String = "Jane Doe", paper: ResumePaperKind = .a4) -> String {
        let preset = ResumePaperSpec.preset(for: paper)
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title)</title>
          <style>
            .resume-page { width: \(preset.cssWidth)px; height: \(preset.cssHeight)px; overflow: hidden; background: #ffffff; }
          </style>
        </head>
        <body>
          <section class="resume-page">
            <h1>\(title)</h1>
          </section>
        </body>
        </html>
        """
    }

    @Test("创建、读取、替换、补丁与删除的完整生命周期")
    func fullCRUD() throws {
        let (store, directory) = makeStorage()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storagePath = directory.path

        // 创建：slug 规范化（大写转小写）。
        let created = try store.createResume(
            storagePath: storagePath,
            slug: "Jane-Doe",
            title: "Jane Doe",
            paper: .a4,
            template: .modern
        )
        #expect(created.document.id == "jane-doe")
        #expect(created.document.title == "Jane Doe")
        #expect(created.document.paper == .a4)
        #expect(created.document.template == .modern)
        #expect(created.html.contains("resume-page"))

        // 读取。
        let read = try store.readResume(storagePath: storagePath, slug: "jane-doe")
        #expect(read.html == created.html)

        // 替换：更新 updatedAt 并写回合法 HTML。
        let newHTML = validHTML(title: "Jane Doe", paper: .a4)
        let replaced = try store.replaceHTML(newHTML, storagePath: storagePath, slug: "jane-doe")
        #expect(replaced.html.contains("Jane Doe"))
        #expect(replaced.document.updatedAt >= created.document.updatedAt)

        // 补丁：原子替换唯一文本。
        let patched = try store.patchHTML(
            operations: [.init(oldText: "<h1>Jane Doe</h1>", newText: "<h1>Jane Doe, PMP</h1>")],
            storagePath: storagePath,
            slug: "jane-doe"
        )
        #expect(patched.html.contains("Jane Doe, PMP"))
        #expect(!patched.html.contains("<h1>Jane Doe</h1>"))

        // 删除后不可再读。
        try store.deleteResume(storagePath: storagePath, slug: "jane-doe")
        #expect(throws: ResumeStoreError.notFound(directory.appendingPathComponent("resumes/jane-doe").path)) {
            _ = try store.readResume(storagePath: storagePath, slug: "jane-doe")
        }
    }

    @Test("非法 slug 与重复创建分别抛错")
    func rejectsInvalidSlugAndDuplicate() throws {
        let (store, directory) = makeStorage()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storagePath = directory.path

        #expect(throws: ResumeStoreError.invalidSlug("Bad Slug!")) {
            _ = try store.createResume(
                storagePath: storagePath,
                slug: "Bad Slug!",
                title: "T",
                paper: .letter,
                template: .blank
            )
        }

        _ = try store.createResume(
            storagePath: storagePath,
            slug: "same",
            title: "Same",
            paper: .a4,
            template: .minimal
        )
        #expect(throws: ResumeStoreError.alreadyExists(directory.appendingPathComponent("resumes/same").path)) {
            _ = try store.createResume(
                storagePath: storagePath,
                slug: "same",
                title: "Same Again",
                paper: .a4,
                template: .minimal
            )
        }
    }

    @Test("补丁要求旧文本唯一，缺失或重复均抛错")
    func patchRequiresUniqueOldText() throws {
        let (store, directory) = makeStorage()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storagePath = directory.path

        _ = try store.createResume(
            storagePath: storagePath,
            slug: "patch-me",
            title: "Patch Me",
            paper: .a4,
            template: .blank
        )

        // 缺失：oldText 不存在。
        #expect(throws: ResumeStoreError.patchTextMissing("no such text")) {
            _ = try store.patchHTML(
                operations: [.init(oldText: "no such text", newText: "x")],
                storagePath: storagePath,
                slug: "patch-me"
            )
        }

        // 不唯一：替换空串会命中多次。
        #expect(throws: ResumeStoreError.patchTextNotUnique(" ")) {
            _ = try store.patchHTML(
                operations: [.init(oldText: " ", newText: "-")],
                storagePath: storagePath,
                slug: "patch-me"
            )
        }
    }

    @Test("listResumes 返回全部简历并按更新时间倒序")
    func listsResumesNewestFirst() throws {
        let (store, directory) = makeStorage()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storagePath = directory.path

        _ = try store.createResume(
            storagePath: storagePath,
            slug: "older",
            title: "Older",
            paper: .a4,
            template: .classic
        )
        Thread.sleep(forTimeInterval: 0.05)
        _ = try store.createResume(
            storagePath: storagePath,
            slug: "newer",
            title: "Newer",
            paper: .letter,
            template: .modern
        )

        let documents = try store.listResumes(storagePath: storagePath)
        #expect(documents.map(\.id) == ["newer", "older"])
        #expect(documents.map(\.title) == ["Newer", "Older"])
    }
}
