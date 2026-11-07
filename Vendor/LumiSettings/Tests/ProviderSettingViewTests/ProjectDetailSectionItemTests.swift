import SwiftUI
import Testing
@testable import ProviderSettingView

/// `ProjectDetailSectionItem` 的字段与分区视图构造行为。
@Suite("项目详情分区模型")
@MainActor
struct ProjectDetailSectionItemTests {

    @Test("默认 order 为 200，字段按构造参数赋值")
    func sectionItemCarriesFields() {
        let section = SectionFixture.section("stats")

        #expect(section.id == "stats")
        #expect(section.order == 200)
    }

    @Test("可显式指定 order")
    func sectionItemAcceptsCustomOrder() {
        #expect(SectionFixture.section("stats", order: 50).order == 50)
    }

    @Test("分区视图闭包接收 path 参数")
    func sectionItemReceivesPath() {
        var receivedPath: String?
        let section = ProjectDetailSectionItem(id: "stats") { path in
            receivedPath = path
            return Text(path)
        }

        _ = section.makeView("general/project")

        #expect(receivedPath == "general/project")
    }

    @Test("每次调用分区闭包都会重新构造视图")
    func sectionItemRebuildsView() {
        var buildCount = 0
        let section = ProjectDetailSectionItem(id: "stats") { _ in
            buildCount += 1
            return Text("section")
        }

        #expect(buildCount == 0)
        _ = section.makeView("a")
        _ = section.makeView("b")

        #expect(buildCount == 2)
    }
}
