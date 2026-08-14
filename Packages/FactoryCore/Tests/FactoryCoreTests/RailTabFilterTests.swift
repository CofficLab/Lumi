import KernelLumi
import SwiftUI
import XCTest

@testable import FactoryCore

/// 验证 `filteredRailTabs` 的「容器专属独占」过滤规则。
///
/// 规则：容器拥有专属 rail tab（`visibility == .viewContainer(id: 容器ID)`）时，
/// 只显示专属 tab；否则维持既有行为。
final class RailTabFilterTests: XCTestCase {

    @MainActor
    private func makeTab(
        id: String,
        visibility: PanelRailTabVisibility = .always,
        requiresProjectSupport: Bool = false,
        requiresActiveProject: Bool = false,
        requiresChatSupport: Bool = false
    ) -> PanelRailTabItem {
        PanelRailTabItem(
            id: id,
            title: id,
            systemImage: "circle",
            visibility: visibility,
            requiresProjectSupport: requiresProjectSupport,
            requiresActiveProject: requiresActiveProject,
            requiresChatSupport: requiresChatSupport
        ) { Text(id) }
    }

    /// 无专属 tab 的容器（默认聊天容器）：维持既有过滤行为。
    @MainActor
    func testNoExclusiveTabKeepsLegacyBehavior() {
        let chats = makeTab(id: "chats", requiresChatSupport: true)
        let explorer = makeTab(id: "explorer", requiresProjectSupport: true)
        let search = makeTab(id: "search")
        let tabs = [chats, explorer, search]

        // 默认聊天容器：支持 chat、不支持项目 → chats + search 可见，explorer 隐藏。
        let result = filteredRailTabs(
            tabs,
            containerID: "default",
            supportsProject: false,
            hasActiveProject: false,
            supportsChat: true
        )
        XCTAssertEqual(result.map(\.id), ["chats", "search"])
    }

    /// 有专属 tab 的容器（Resume）：只显示自己的 rail view，chats 不再混入。
    @MainActor
    func testExclusiveContainerOnlyShowsOwnTabs() {
        let chats = makeTab(id: "chats", requiresChatSupport: true)
        let search = makeTab(id: "search")
        let resume = makeTab(
            id: "resume.sidebar",
            visibility: .viewContainer(id: "resume")
        )
        let tabs = [chats, search, resume]

        let result = filteredRailTabs(
            tabs,
            containerID: "resume",
            supportsProject: false,
            hasActiveProject: false,
            supportsChat: true
        )
        XCTAssertEqual(result.map(\.id), ["resume.sidebar"])
    }

    /// 专属容器连无条件 `.always` 的全局 tab（如 EditorSearch）也会隐藏。
    @MainActor
    func testExclusiveContainerHidesGlobalTabsEvenWithoutRequirements() {
        let search = makeTab(id: "search")
        let booklet = makeTab(
            id: "booklet.sidebar",
            visibility: .viewContainer(id: "booklet")
        )
        let result = filteredRailTabs(
            [search, booklet],
            containerID: "booklet",
            supportsProject: false,
            hasActiveProject: false,
            supportsChat: false
        )
        XCTAssertEqual(result.map(\.id), ["booklet.sidebar"])
    }

    /// 多专属 tab 的容器（Git 的 history + tools）：全部保留，全局 tab 隐藏。
    @MainActor
    func testMultipleExclusiveTabsAllKept() {
        let history = makeTab(
            id: "git.history",
            visibility: .viewContainer(id: "git"),
            requiresProjectSupport: true
        )
        let tools = makeTab(
            id: "git.tools",
            visibility: .viewContainer(id: "git"),
            requiresProjectSupport: true
        )
        let chats = makeTab(id: "chats", requiresChatSupport: true)

        let result = filteredRailTabs(
            [chats, history, tools],
            containerID: "git",
            supportsProject: true,
            hasActiveProject: true,
            supportsChat: true
        )
        XCTAssertEqual(result.map(\.id), ["git.history", "git.tools"])
    }

    /// 专属 tab 因项目支持被过滤时，独占容器显示为空（语义一致：容器声明了专属 rail）。
    @MainActor
    func testExclusiveTabFilteredByProjectSupportLeavesEmpty() {
        let gitTools = makeTab(
            id: "git.tools",
            visibility: .viewContainer(id: "git"),
            requiresProjectSupport: true
        )
        let chats = makeTab(id: "chats", requiresChatSupport: true)

        let result = filteredRailTabs(
            [chats, gitTools],
            containerID: "git",
            supportsProject: false,
            hasActiveProject: false,
            supportsChat: true
        )
        XCTAssertTrue(result.isEmpty)
    }

    /// 需要当前项目的 tab 在未选择项目时隐藏，其他 tab 仍保留。
    @MainActor
    func testActiveProjectRequirementHidesOnlyDependentTab() {
        let explorer = makeTab(
            id: "explorer",
            requiresProjectSupport: true,
            requiresActiveProject: true
        )
        let chats = makeTab(id: "chats", requiresChatSupport: true)

        let result = filteredRailTabs(
            [explorer, chats],
            containerID: "default",
            supportsProject: true,
            hasActiveProject: false,
            supportsChat: true
        )

        XCTAssertEqual(result.map(\.id), ["chats"])
    }

    /// 选择项目后，需要当前项目的 tab 恢复可见。
    @MainActor
    func testActiveProjectRequirementShowsTabWhenProjectSelected() {
        let explorer = makeTab(
            id: "explorer",
            requiresProjectSupport: true,
            requiresActiveProject: true
        )

        let result = filteredRailTabs(
            [explorer],
            containerID: "default",
            supportsProject: true,
            hasActiveProject: true,
            supportsChat: true
        )

        XCTAssertEqual(result.map(\.id), ["explorer"])
    }
}
