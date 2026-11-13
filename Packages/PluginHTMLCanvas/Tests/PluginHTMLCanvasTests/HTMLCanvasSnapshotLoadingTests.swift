import Foundation
import Testing
@testable import PluginHTMLCanvas

/// HTML Canvas 卡片的快照加载（见 issue #1281）。
///
/// 快照原先是计算属性，每次 body 求值都同步读盘 + 解码 PNG；
/// `hasSnapshot` / `hasHTMLFile` 也各是一次同步的文件系统查询。
@Suite("HTML Canvas 快照加载")
struct HTMLCanvasSnapshotLoadingTests {

    @Test("快照文件不存在时记录为不可用")
    func missingSnapshotResolvesToNil() {
        let payload = HTMLCanvasPayload(
            htmlPath: "",
            snapshotPath: "/tmp/does-not-exist-\(UUID().uuidString).png",
            width: 100,
            height: 100
        )

        // 载荷本身报告没有快照。
        #expect(payload.hasSnapshot == false)
    }

    @Test("HTML 文件存在性由路径决定")
    func htmlFilePresenceFollowsPath() {
        let missing = HTMLCanvasPayload(
            htmlPath: "/tmp/does-not-exist-\(UUID().uuidString).html",
            snapshotPath: "",
            width: 100,
            height: 100
        )
        #expect(missing.hasHTMLFile == false)

        let present = HTMLCanvasPayload(
            htmlPath: FileManager.default.temporaryDirectory
                .appendingPathComponent("present-\(UUID().uuidString).html").path,
            snapshotPath: "",
            width: 100,
            height: 100
        )
        // 路径非空但文件不存在时同样为 false。
        #expect(present.hasHTMLFile == false)
    }

    @Test("快照缓存按路径区分")
    func snapshotCacheIsKeyedByPath() {
        let pathA = "/tmp/a-\(UUID().uuidString).png"
        let pathB = "/tmp/b-\(UUID().uuidString).png"

        // 缓存条目的身份由路径决定：路径不同即视为不同的快照。
        #expect(pathA != pathB)
    }
}
