import XCTest

/// PluginMessageListBrief (V1) 过程折叠区的**滚动** UI 测试。
///
/// ## 用户报告的症状
///
/// 展开过程折叠区后：
///
/// - 鼠标拖动右侧滚动条 → **能滚**；
/// - 滚动触控板 / 滚轮 → **滚不动**。
///
/// ## 根因与本测试的守卫点
///
/// 根因是折叠区只用 `.frame(maxHeight:)` 限定 `ScrollView` 高度：
/// `ScrollView` 的固有高度等于**内容高度**，`List` 把这一行裁到上限时，
/// SwiftUI 会把内层 clipView 的可视高度一并压成 **0** ——
///
/// - 内层没有可视区域 → 滚轮与拖拽都无处可滚；
/// - 拖动滚动条直接操作 scroller 几何、不依赖可视区域 → 仍能拖动。
///
/// 修复是给限高 frame 加 `minHeight`。
///
/// ## 为什么判据必须读内层几何
///
/// 这个 bug 的所有外部观察都有歧义：
///
/// - AX 帧：未物化的行在列表坐标系里也有布局位置（实测 y≈3954），
///   拿它们当判据只会得到恒定的「没变化」；
/// - 合成滚轮事件：SwiftUI 的 `ScrollView` **不接受**任何投到窗口上的
///   合成事件（实测：原生 `NSScrollView` 接受 `wheel1` 垂直增量，
///   SwiftUI 的 `HostingScrollView` 一律 Δ=0，无论是否带 phase、
///   无论投到 `.cghidEventTap` 还是 `.cgSessionEventTap`）。
///
/// 因此折叠区在 DEBUG 下把内层几何（`offset/documentHeight/visibleHeight`）
/// 通过一个隐藏的 AX 元素暴露出来（见 `ProcessSectionGeometryProbe`），
/// 本测试直接断言这个值。
final class LumiProcessSectionScrollUITests: LumiUITestCase {

    // MARK: - Constants

    /// 折叠区的可访问性标识符。
    private enum Section {
        /// 过程折叠区容器。
        static let container = "lumi.message-list-brief.process-section"

        /// 内层滚动视图的实时几何。
        static let geometry = "lumi.message-list-brief.process-section.geometry"
    }

    /// 长流程 turn 的用户消息文案。
    private static let longFlowAnchor = "执行长流程操作"

    /// 短流程 turn 的用户消息文案（3 个步骤）。
    private static let shortFlowAnchor = "执行三步操作"

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            "--lumi-ui-testing-message-list-brief",
            "--lumi-ui-testing-isolated-storage",
        ])
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Cases

    /// 内容超限时，内层 clipView 必须有**非零**的可视高度。
    ///
    /// - Important: 这是「滚不动」的直接机制，也是本 bug 的守卫点。
    ///   可视高度为 0 时滚轮无处可滚，而拖动滚动条仍然可用
    ///   （拖动直接操作 scroller 几何，不依赖 clipView 的可视区域）——
    ///   与用户报告的现象完全吻合。
    func testOverflowingSectionHasNonZeroViewportHeight() throws {
        let frame = try expandSection(userMessage: Self.longFlowAnchor)

        let geometry = try readGeometry(near: frame)
        print("🖱 [viewport] visible=\(geometry.visibleHeight) document=\(geometry.documentHeight) maxOffset=\(geometry.maxOffset)")

        XCTAssertGreaterThan(
            geometry.visibleHeight,
            0,
            """
            内层 clipView 的可视高度必须大于 0。\
            实际=\(geometry.visibleHeight)\
            —— 高度为 0 时滚轮无处可滚，表现为「拖滚动条能滚、滚轮不能滚」。
            """
        )

        XCTAssertGreaterThan(
            geometry.documentHeight,
            geometry.visibleHeight,
            """
            内容应超出视口高度（否则折叠区没有可滚空间）。\
            document=\(geometry.documentHeight) visible=\(geometry.visibleHeight)
            """
        )
    }

    /// 内容短于上限时，高度仍自适应（不占满上限）。
    ///
    /// - Important: 守卫 `minHeight: 1`（而不是 `minHeight: maxHeight`）
    ///   带来的视觉语义：短内容折叠区不应拖着一大片空白。
    func testShortSectionStaysAdaptive() throws {
        let frame = try expandSection(userMessage: Self.shortFlowAnchor)

        let geometry = try readGeometry(near: frame)
        print("🖱 [adaptive] visible=\(geometry.visibleHeight) document=\(geometry.documentHeight)")

        XCTAssertGreaterThan(
            geometry.visibleHeight,
            0,
            "内层 clipView 的可视高度必须大于 0，实际=\(geometry.visibleHeight)"
        )

        XCTAssertEqual(
            geometry.visibleHeight,
            geometry.documentHeight,
            accuracy: 1,
            """
            内容短于上限时高度应自适应（视口高度 = 内容高度，不占满上限）。\
            visible=\(geometry.visibleHeight) document=\(geometry.documentHeight)
            """
        )
    }

    // MARK: - Helpers

    /// 展开指定 turn 的过程折叠区，并返回它自己的折叠区容器帧。
    ///
    /// - Important: 折叠区标题都是「执行了N个步骤」，只能靠**位置**区分
    ///   不同 turn 的折叠区。这里用「对应 turn 的用户消息在 AX 树里的位置」
    ///   找到它下方最近的折叠区 —— 比「取最靠下的那个」精确：
    ///   后者会把短流程用例也展开成长流程那个折叠区。
    @discardableResult
    private func expandSection(userMessage: String) throws -> CGRect {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪"
        )
        let anchor = element(anyLabelOf: [userMessage])
        XCTAssertTrue(
            anchor.waitForExistence(timeout: 25),
            "夹具 turn 的用户消息「\(userMessage)」未出现"
        )

        let disclosures = allElements(containingLabel: "执行了")
        XCTAssertFalse(disclosures.isEmpty, "过程折叠区折叠态未出现")

        // 找「用户消息下方最近的那个折叠区」。
        let anchorFrame = anchor.frame
        let disclosure = try XCTUnwrap(
            disclosures
                .filter { $0.frame.minY >= anchorFrame.minY }
                .min(by: { $0.frame.minY < $1.frame.minY }),
            "找不到用户消息「\(userMessage)」下方的过程折叠区"
        )
        disclosure.click()

        // 折叠区容器（展开后才有）落在标题行下方。
        let containers = app.descendants(matching: .any)
            .matching(identifier: Section.container)
            .allElementsBoundByIndex
        let container = containers
            .filter { $0.frame.minY >= disclosure.frame.minY }
            .min(by: { $0.frame.minY < $1.frame.minY })
        return container?.frame ?? disclosure.frame
    }

    /// 读取折叠区上报的内层几何（带等待）。
    ///
    /// - Parameter near: 目标折叠区的帧。AX 树里可能有**多个**几何探针
    ///   （每个展开的折叠区一个），必须挑帧位置就近的那一个 ——
    ///   取「第一个匹配」会读到别的折叠区的几何。
    private func readGeometry(
        near targetFrame: CGRect? = nil
    ) throws -> (offset: Double, documentHeight: Double, visibleHeight: Double, maxOffset: Double) {
        let probes = app.descendants(matching: .any)
            .matching(identifier: Section.geometry)
            .allElementsBoundByIndex
        XCTAssertFalse(probes.isEmpty, "几何探针元素未出现")

        // 等探针上报第一个几何值。
        //
        // - Important: 几何挂在 `accessibilityValue` 上（不是 label）——
        //   `Text` 的 label 会被它自己的文本内容覆盖，读不到动态值。
        var raw = ""
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            // 在所有探针里挑「离目标折叠区**容器**最近、且已有几何值」的那个。
            //
            // - Important: 探针元素在折叠区**内部**（内容顶部），它与折叠区
            //   标题行的 y 差可达一整段内容高度，不能用固定阈值过滤。
            //   必须拿折叠区**容器**的帧做锚点。
            let containers = app.descendants(matching: .any)
                .matching(identifier: Section.container)
                .allElementsBoundByIndex
            var best: (raw: String, distance: CGFloat)?
            for probe in probes {
                let candidate = probe.value as? String ?? ""
                guard candidate.contains("/") else { continue }
                let distance = targetFrame.map { target in
                    containers.map { abs($0.frame.minY - target.minY) }.min() ?? 0
                } ?? 0
                if best == nil || distance < best!.distance {
                    best = (candidate, distance)
                }
            }
            if let best {
                raw = best.raw
                break
            }
            usleep(200_000)
        }

        let parts = raw.split(separator: "/")
        XCTAssertEqual(
            parts.count,
            3,
            "几何格式应为 offset/documentHeight/visibleHeight，实际=\(raw)"
        )
        guard parts.count == 3,
              let offset = Double(parts[0]),
              let document = Double(parts[1]),
              let visible = Double(parts[2]) else {
            XCTFail("几何无法解析：\(raw)")
            throw XCTSkip("几何无法解析")
        }
        return (offset, document, visible, max(0, document - visible))
    }

    /// 全部 label / value **包含**指定片段的元素。
    private func allElements(containingLabel fragment: String) -> [XCUIElement] {
        app.descendants(matching: .any)
            .matching(
                NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", fragment, fragment)
            )
            .allElementsBoundByIndex
    }
}
