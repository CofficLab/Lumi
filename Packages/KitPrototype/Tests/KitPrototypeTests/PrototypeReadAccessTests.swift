import Foundation
import Testing

@testable import KitPrototype

/// 屏幕预览与导出的 WebKit 读取权限必须覆盖项目根，官方 `../assets/...`
/// 引用路径才能加载；只授予屏幕目录会拦截共享素材（回归 #324）。
@Suite("Prototype read access root")
@MainActor
struct PrototypeReadAccessTests {

    @Test("导出读取权限根是屏幕 HTML 的上上级目录（项目根）")
    func exportReadAccessRootIsProjectDirectory() {
        let project = URL(fileURLWithPath: "/tmp/lumi-324-proj")
        let screenHTML = project
            .appendingPathComponent("screen-a", isDirectory: true)
            .appendingPathComponent("index.html")

        #expect(
            PrototypeHTMLExporter.readAccessRoot(forScreenHTML: screenHTML)
                .standardizedFileURL.path == project.standardizedFileURL.path
        )
    }

    @Test("ResolvedScreen 的项目根目录是屏幕目录的上级")
    func resolvedScreenProjectDirectoryIsScreenParent() {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-324-\(UUID().uuidString)", isDirectory: true)
        let screenDir = project.appendingPathComponent("screen-a", isDirectory: true)
        let resolved = PrototypeResolvedScreen(
            project: PrototypeProject(
                id: "p1",
                title: "P",
                device: PrototypeDevice(kind: .custom, width: 393, height: 852, scale: 2)
            ),
            screen: PrototypeScreen(id: "screen-a", title: "A", order: 0),
            directoryURL: screenDir,
            html: "<img src=\"../assets/foo.png\">"
        )

        #expect(resolved.projectDirectoryURL.standardizedFileURL.path == project.standardizedFileURL.path)
    }
}
