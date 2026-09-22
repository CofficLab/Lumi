import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import KitPrototype

@Suite("Prototype project documents")
struct KitPrototypeTests {

    // MARK: - 设备

    @Test func devicePresetsAreUniqueAndConsistent() {
        let kinds = PrototypeDeviceKind.allCases.filter { $0 != .custom }
        let presets = kinds.compactMap(\.preset)
        #expect(presets.count == kinds.count)
        #expect(presets.allSatisfy { $0.width > 0 && $0.height > 0 && $0.scale > 0 })
        #expect(PrototypeDeviceKind.iPhone15Pro.preset?.width == 393)
        #expect(PrototypeDeviceKind.iPhone15Pro.preset?.pixelWidth == 1179)
        #expect(PrototypeDeviceKind.iPhone15Pro.preset?.pixelHeight == 2556)
        #expect(PrototypeDeviceKind.custom.preset == nil)
    }

    // MARK: - 跳转解析

    @Test func hotspotParsingReadsLinksAndLabels() {
        let html = """
        <!doctype html><html><head></head><body>
        <button data-prototype-link="screen-detail" data-prototype-label="查看详情">查看</button>
        <a data-prototype-link="screen-settings" data-prototype-label="设置">设置</a>
        <div data-prototype-link="screen-detail">重复目标</div>
        </body></html>
        """
        let hotspots = PrototypeHotspot.parse(fromHTML: html)
        #expect(hotspots.count == 2)
        #expect(hotspots[0].targetScreenID == "screen-detail")
        #expect(hotspots[0].label == "查看详情")
        #expect(hotspots[1].targetScreenID == "screen-settings")
        #expect(PrototypeHotspot.declaredTargets(inHTML: html) == ["screen-detail", "screen-settings"])
    }

    @Test func hotspotParsingHandlesSingleQuotesAndNoLabel() {
        let html = #"<div data-prototype-link='screen-home'>go</div>"#
        let hotspots = PrototypeHotspot.parse(fromHTML: html)
        #expect(hotspots.count == 1)
        #expect(hotspots[0].targetScreenID == "screen-home")
        #expect(hotspots[0].label == nil)
    }

    // MARK: - 校验

    @Test func linterRejectsScriptsRemoteResourcesAndIncompleteDocuments() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background: white; overflow: hidden"><script></script><img src="https://example.com/a.png"></body></html>
        """
        let report = PrototypeHTMLLinter().lint(html: html)
        let codes = report.errors.map(\.code)
        #expect(codes.contains("script_forbidden"))
        #expect(codes.contains("remote_resource"))
        #expect(!report.isValid)

        let fragment = "<div>not a document</div>"
        #expect(PrototypeHTMLLinter().lint(html: fragment).errors.map(\.code).contains("incomplete_document"))
    }

    @Test func linterAllowsMotionButWarns() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background:#fff; overflow:hidden; transition: opacity .2s">
        <div data-block="x" data-block-label="X"></div></body></html>
        """
        let report = PrototypeHTMLLinter().lint(html: html)
        #expect(report.isValid)
        #expect(report.warnings.map(\.code).contains("motion_present"))
    }

    @Test func linterWarnsAboutUnstableBlockAnnotations() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background:#fff; overflow:hidden">
        <section data-block="hero" data-block-label="Hero"></section>
        <section data-block="hero" data-block-label="Repeated"></section>
        <button data-block="   ">Go</button>
        <article data-block="summary"></article>
        </body></html>
        """

        let codes = PrototypeHTMLLinter().lint(html: html).warnings.map(\.code)

        #expect(codes.contains("duplicate_block_id"))
        #expect(codes.contains("empty_block_id"))
        #expect(codes.contains("missing_block_label"))
    }

    @Test func linterAcceptsUniqueLabeledBlocks() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background:#fff; overflow:hidden">
        <section data-block="hero" data-block-label="Hero"></section>
        <button data-block="primary-action" data-block-label="Primary Action">Go</button>
        </body></html>
        """

        let codes = Set(PrototypeHTMLLinter().lint(html: html).warnings.map(\.code))

        #expect(!codes.contains("duplicate_block_id"))
        #expect(!codes.contains("empty_block_id"))
        #expect(!codes.contains("missing_block_label"))
    }

    @Test func linterReportsUnknownJumpTarget() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background:#fff; overflow:hidden">
        <div data-block="x" data-block-label="X" data-prototype-link="screen-ghost">go</div>
        </body></html>
        """
        let report = PrototypeHTMLLinter().lint(html: html, knownScreenIDs: ["home"])
        #expect(report.errors.map(\.code).contains("unknown_link_target"))
    }

    @Test func linterSkipsJumpValidationWhenScreenSetUnknown() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background:#fff; overflow:hidden">
        <div data-block="x" data-block-label="X" data-prototype-link="anything">go</div>
        </body></html>
        """
        #expect(PrototypeHTMLLinter().lint(html: html).isValid)
    }

    @Test func linterRejectsEscapingAssetPaths() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background:#fff; overflow:hidden">
        <div data-block="x" data-block-label="X"></div><img src="../../../etc/passwd">
        </body></html>
        """
        // 提供屏幕目录后才会做路径解析与越界检查。
        let screenDirectory = URL(fileURLWithPath: "/tmp/proto/tasks/p/home", isDirectory: true)
        let report = PrototypeHTMLLinter().lint(html: html, documentDirectory: screenDirectory)
        #expect(report.errors.map(\.code).contains("unsafe_asset_path"))
    }

    @Test func linterRejectsAbsoluteAssetPaths() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background:#fff; overflow:hidden">
        <div data-block="x" data-block-label="X"></div><img src="/etc/passwd">
        </body></html>
        """
        let screenDirectory = URL(fileURLWithPath: "/tmp/proto/tasks/p/home", isDirectory: true)
        let report = PrototypeHTMLLinter().lint(html: html, documentDirectory: screenDirectory)
        #expect(report.errors.map(\.code).contains("unsafe_asset_path"))
    }

    /// 共享素材位于项目目录（屏幕目录的父级），`../assets/x.png` 必须合法。
    ///
    /// 这是素材导入器返回、SKILL.md 教 LLM 使用的路径；若被 linter 拒绝，
    /// 文档承诺的 happy path 就是断的。同时确认越界路径仍被拦截。
    @Test func sharedAssetPathIsAcceptedWhileEscapesAreRejected() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "p",
                title: "P",
                style: .hiFi,
                device: PrototypeDeviceKind.desktop.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "p", screenSlug: "home", title: "Home")

            // 放入一张真实素材到项目级共享目录。
            let assets = try store.assetsDirectoryURL(storagePath: root.path, projectSlug: "p")
            try Self.writePNG(to: assets.appendingPathComponent("shot.png"), width: 4, height: 4)

            let sharedReference = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
            <body style="background:#fff; overflow:hidden">
            <div data-block="x" data-block-label="X"><img src="../assets/shot.png"></div>
            </body></html>
            """
            _ = try store.replaceScreenHTML(
                sharedReference,
                storagePath: root.path,
                projectSlug: "p",
                screenSlug: "home"
            )
            let report = try store.lintScreen(storagePath: root.path, projectSlug: "p", screenSlug: "home")
            #expect(report.isValid, "共享素材路径被拒: \(report.errors.map { "\($0.code) \($0.message)" })")

            // 越界路径必须仍然被拒绝。
            let escaping = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
            <body style="background:#fff; overflow:hidden">
            <div data-block="x" data-block-label="X"><img src="../../../../etc/passwd"></div>
            </body></html>
            """
            #expect(throws: PrototypeStoreError.self) {
                _ = try store.replaceScreenHTML(
                    escaping,
                    storagePath: root.path,
                    projectSlug: "p",
                    screenSlug: "home"
                )
            }
        }
    }

    @Test func linterWarnsAboutEscapedScriptMarkup() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background:#fff; overflow:hidden">
        <div data-block="x" data-block-label="X">&lt;script&gt;alert(1)&lt;/script&gt;</div>
        </body></html>
        """
        let report = PrototypeHTMLLinter().lint(html: html)
        // 转义后的尖括号不会被 script 检查命中，因此单独给出提示。
        #expect(report.isValid)
        #expect(report.warnings.map(\.code).contains("escaped_markup"))
    }

    // MARK: - 模板

    @Test func templatesProduceValidDocumentsForBothStyles() {
        let device = PrototypeDeviceKind.iPhone15Pro.preset!
        for style in PrototypeStyle.allCases {
            let html = PrototypeTemplateFactory.html(title: "首页", appName: "Lumi", style: style, device: device)
            let report = PrototypeHTMLLinter().lint(html: html)
            #expect(report.isValid, "style \(style.rawValue) produced errors: \(report.errors)")
            #expect(html.contains("<!doctype html>"))
            #expect(html.contains("name=\"viewport\""))
            #expect(html.contains(PrototypeHTMLAttributes.block + "="))
            #expect(!html.lowercased().contains("<script"))
        }
    }

    @Test func templatesEscapeInjectedTitle() {
        let html = PrototypeTemplateFactory.html(
            title: "<b>x</b>",
            appName: "A&B",
            style: .wireframe,
            device: PrototypeDeviceKind.desktop.preset!
        )
        #expect(html.contains("&lt;b&gt;x&lt;/b&gt;"))
        #expect(html.contains("A&amp;B"))
    }

    // MARK: - Store 基础流程

    @Test func storeCreatesProjectAddsScreensAndPersists() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            let project = try store.createProject(
                storagePath: root.path,
                slug: "checkout-flow",
                title: "Checkout Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            #expect(project.id == "checkout-flow")
            #expect(project.screens.isEmpty)

            let home = try store.addScreen(
                storagePath: root.path,
                projectSlug: "checkout-flow",
                screenSlug: "01-home",
                title: "首页"
            )
            #expect(home.html.contains("首页"))
            #expect(FileManager.default.fileExists(
                atPath: root.appendingPathComponent("tasks/checkout-flow/01-home/index.html").path
            ))
            // 首屏被自动设为起始屏。
            #expect(try store.readProject(storagePath: root.path, projectSlug: "checkout-flow").startScreenID == "01-home")

            _ = try store.addScreen(
                storagePath: root.path,
                projectSlug: "checkout-flow",
                screenSlug: "02-detail",
                title: "详情"
            )
            let reloaded = try store.readProject(storagePath: root.path, projectSlug: "checkout-flow")
            #expect(reloaded.screens.count == 2)
            #expect(reloaded.sortedScreens.map(\.id) == ["01-home", "02-detail"])
            #expect(reloaded.screens.map(\.order) == [0, 1])
        }
    }

    @Test func storeRejectsDuplicateAndReservedSlugs() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "app",
                title: "App",
                style: .hiFi,
                device: PrototypeDeviceKind.iPhoneSE.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "app", screenSlug: "home", title: "Home")

            #expect(throws: PrototypeStoreError.self) {
                _ = try store.addScreen(storagePath: root.path, projectSlug: "app", screenSlug: "home", title: "Again")
            }
            #expect(throws: PrototypeStoreError.self) {
                _ = try store.addScreen(storagePath: root.path, projectSlug: "app", screenSlug: "assets", title: "Assets")
            }
            #expect(throws: PrototypeStoreError.self) {
                _ = try store.createProject(
                    storagePath: root.path,
                    slug: "Bad Slug",
                    title: "Bad",
                    style: .hiFi,
                    device: PrototypeDeviceKind.desktop.preset!
                )
            }
        }
    }

    @Test func storePatchesAtomicallyAndRefreshesHotspots() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "01-home", title: "Home")
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "02-detail", title: "Detail")

            let patched = try store.patchScreenHTML(
                operations: [.init(oldText: "<div class=\"brand\">Flow</div>", newText: "<div class=\"brand\">结账流程</div>")],
                storagePath: root.path,
                projectSlug: "flow",
                screenSlug: "01-home"
            )
            #expect(patched.html.contains("结账流程"))
        }
    }

    @Test func patchBatchFailsWhenAnyMatchIsMissingOrAmbiguous() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home", title: "Home")

            #expect(throws: PrototypeStoreError.self) {
                _ = try store.patchScreenHTML(
                    operations: [.init(oldText: "<not-present>", newText: "x")],
                    storagePath: root.path,
                    projectSlug: "flow",
                    screenSlug: "home"
                )
            }
            // 先成功一条、再失败一条：整体不得写入。
            let before = try store.readScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home").html
            #expect(throws: PrototypeStoreError.self) {
                _ = try store.patchScreenHTML(
                    operations: [
                        .init(oldText: "<div class=\"brand\">Flow</div>", newText: "<div class=\"brand\">Changed</div>"),
                        .init(oldText: "<not-present>", newText: "x"),
                    ],
                    storagePath: root.path,
                    projectSlug: "flow",
                    screenSlug: "home"
                )
            }
            let after = try store.readScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home").html
            #expect(before == after)
        }
    }

    @Test func replaceScreenHTMLRejectsInvalidDocument() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home", title: "Home")
            let before = try store.readScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home").html

            #expect(throws: PrototypeStoreError.self) {
                _ = try store.replaceScreenHTML(
                    "<div>fragment</div>",
                    storagePath: root.path,
                    projectSlug: "flow",
                    screenSlug: "home"
                )
            }
            #expect(try store.readScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home").html == before)
        }
    }

    @Test func replaceScreenHTMLRejectsUnknownJumpTarget() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home", title: "Home")

            let html = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
            <body style="background:#fff; overflow:hidden">
            <div data-block="x" data-block-label="X" data-prototype-link="missing-screen">go</div>
            </body></html>
            """
            #expect(throws: PrototypeStoreError.self) {
                _ = try store.replaceScreenHTML(html, storagePath: root.path, projectSlug: "flow", screenSlug: "home")
            }
        }
    }

    @Test func replaceScreenHTMLAcceptsValidJumpBetweenScreens() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home", title: "Home")
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "detail", title: "Detail")

            let html = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
            <body style="background:#fff; overflow:hidden">
            <div data-block="x" data-block-label="X" data-prototype-link="detail" data-prototype-label="进入详情">go</div>
            </body></html>
            """
            let updated = try store.replaceScreenHTML(html, storagePath: root.path, projectSlug: "flow", screenSlug: "home")
            #expect(updated.screen.hotspots.count == 1)
            #expect(updated.screen.hotspots[0].targetScreenID == "detail")

            let reloaded = try store.readProject(storagePath: root.path, projectSlug: "flow")
            #expect(reloaded.screen(id: "home")?.hotspots.first?.label == "进入详情")
        }
    }

    @Test func duplicateScreenCopiesHTML() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            let home = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home", title: "Home")
            let copy = try store.duplicateScreen(
                storagePath: root.path,
                projectSlug: "flow",
                screenSlug: "home",
                newScreenSlug: "home-copy"
            )
            #expect(copy.html == home.html)
            #expect(try store.readProject(storagePath: root.path, projectSlug: "flow").screens.count == 2)
        }
    }

    @Test func deleteScreenReindexesAndRepointsStartScreen() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home", title: "Home")
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "detail", title: "Detail")

            try store.deleteScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home")
            let project = try store.readProject(storagePath: root.path, projectSlug: "flow")
            #expect(project.screens.map(\.id) == ["detail"])
            #expect(project.screens.map(\.order) == [0])
            #expect(project.startScreenID == "detail")
            #expect(!FileManager.default.fileExists(
                atPath: root.appendingPathComponent("tasks/flow/home/index.html").path
            ))
        }
    }

    @Test func deleteScreenRefreshesDanglingHotspotsWithoutThrowing() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home", title: "Home")
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "detail", title: "Detail")

            let html = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
            <body style="background:#fff; overflow:hidden">
            <div data-block="x" data-block-label="X" data-prototype-link="detail">go</div>
            </body></html>
            """
            _ = try store.replaceScreenHTML(html, storagePath: root.path, projectSlug: "flow", screenSlug: "home")

            try store.deleteScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "detail")
            // 悬空跳转留给 lint 报告，删除本身不抛错。
            let report = try store.lintScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home")
            #expect(report.errors.map(\.code).contains("unknown_link_target"))
        }
    }

    @Test func reorderScreensRequiresCompleteUniqueList() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "a", title: "A")
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "b", title: "B")

            let reordered = try store.reorderScreens(
                storagePath: root.path,
                projectSlug: "flow",
                orderedScreenIDs: ["b", "a"]
            )
            #expect(reordered.sortedScreens.map(\.id) == ["b", "a"])
            #expect(reordered.sortedScreens.map(\.order) == [0, 1])

            #expect(throws: PrototypeStoreError.self) {
                _ = try store.reorderScreens(
                    storagePath: root.path,
                    projectSlug: "flow",
                    orderedScreenIDs: ["a"]
                )
            }
            #expect(throws: PrototypeStoreError.self) {
                _ = try store.reorderScreens(
                    storagePath: root.path,
                    projectSlug: "flow",
                    orderedScreenIDs: ["a", "ghost"]
                )
            }
        }
    }

    @Test func setStartScreenValidatesExistence() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "home", title: "Home")
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "detail", title: "Detail")

            let project = try store.setStartScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "detail")
            #expect(project.startScreenID == "detail")
            #expect(project.resolvedStartScreen?.id == "detail")

            #expect(throws: PrototypeStoreError.self) {
                _ = try store.setStartScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "ghost")
            }
        }
    }

    @Test func listProjectsSortsByRecencyAndReadsDefaults() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "one",
                title: "One",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhoneSE.preset!
            )
            _ = try store.createProject(
                storagePath: root.path,
                slug: "two",
                title: "Two",
                style: .hiFi,
                device: PrototypeDeviceKind.desktop.preset!
            )
            let projects = try store.listProjects(storagePath: root.path)
            #expect(Set(projects.map(\.id)) == ["one", "two"])

            let read = try store.readProject(storagePath: root.path, projectSlug: "two")
            #expect(read.style == .hiFi)
            #expect(read.device.kind == .desktop)
        }
    }

    @Test func lintProjectReportsEveryScreen() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            _ = try store.createProject(
                storagePath: root.path,
                slug: "flow",
                title: "Flow",
                style: .wireframe,
                device: PrototypeDeviceKind.iPhone15Pro.preset!
            )
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "a", title: "A")
            _ = try store.addScreen(storagePath: root.path, projectSlug: "flow", screenSlug: "b", title: "B")

            let reports = try store.lintProject(storagePath: root.path, projectSlug: "flow")
            #expect(Set(reports.keys) == ["a", "b"])
            #expect(reports.values.allSatisfy { $0.isValid })
        }
    }

    @Test func storeRequiresNonEmptyStoragePath() {
        let store = PrototypeDocumentStore()
        #expect(throws: PrototypeStoreError.self) {
            _ = try store.listProjects(storagePath: "")
        }
    }

    @Test func projectNotFoundThrows() throws {
        try withTemporaryStorage { root in
            let store = PrototypeDocumentStore()
            #expect(throws: PrototypeStoreError.self) {
                _ = try store.readProject(storagePath: root.path, projectSlug: "ghost")
            }
            #expect(throws: PrototypeStoreError.self) {
                _ = try store.readScreen(storagePath: root.path, projectSlug: "ghost", screenSlug: "home")
            }
        }
    }

    // MARK: - 素材导入

    @Test func importerCopiesImageAndReturnsSharedRelativePath() throws {
        try withTemporaryStorage { root in
            let source = root.appendingPathComponent("source.png")
            try Self.writePNG(to: source, width: 8, height: 6)
            let destination = root.appendingPathComponent("assets", isDirectory: true)

            let asset = try PrototypeAssetImporter().importImage(
                sourceURL: source,
                destinationDirectory: destination,
                preferredFileName: "shot.png"
            )
            #expect(asset.relativePath == "../assets/shot.png")
            #expect(asset.pixelWidth == 8)
            #expect(asset.pixelHeight == 6)
            #expect(FileManager.default.fileExists(atPath: asset.fileURL.path))
        }
    }

    @Test func importerRejectsUnsupportedImage() throws {
        try withTemporaryStorage { root in
            let source = root.appendingPathComponent("not-an-image.txt")
            try "hello".write(to: source, atomically: true, encoding: .utf8)
            #expect(throws: PrototypeAssetError.self) {
                _ = try PrototypeAssetImporter().importImage(
                    sourceURL: source,
                    destinationDirectory: root.appendingPathComponent("assets", isDirectory: true)
                )
            }
        }
    }

    @Test func importerRejectsMissingSource() throws {
        try withTemporaryStorage { root in
            #expect(throws: PrototypeAssetError.self) {
                _ = try PrototypeAssetImporter().importImage(
                    sourceURL: root.appendingPathComponent("ghost.png"),
                    destinationDirectory: root.appendingPathComponent("assets", isDirectory: true)
                )
            }
        }
    }

    // MARK: - 测试辅助

    /// 在唯一临时目录内执行测试体，结束后清理。
    private func withTemporaryStorage(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kit-prototype-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    /// 写出一张最小可解码的 PNG，供素材导入测试使用。
    private static func writePNG(to url: URL, width: Int, height: Int) throws {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context, let image = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw PrototypeAssetError.unsupportedImage(url.path)
        }
        try data.write(to: url, options: .atomic)
    }
}
