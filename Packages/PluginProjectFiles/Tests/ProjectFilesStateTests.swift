import Foundation
import KernelLumi
import Testing
@testable import ProjectFilesPlugin

@Suite("Project Files State")
struct ProjectFilesStateTests {
    private func makeTab(
        _ id: String,
        path: String?,
        isDirty: Bool = false
    ) -> EditorSessionTab {
        EditorSessionTab(
            id: EditorSessionID(rawValue: UUID(uuidString: id) ?? UUID()),
            documentID: .makeUnique(),
            uri: path.map { URL(fileURLWithPath: $0) },
            title: path.map { ($0 as NSString).lastPathComponent } ?? "untitled",
            isDirty: isDirty
        )
    }

    private func makeWorkbench(
        _ tabs: [EditorSessionTab],
        active: EditorSessionID?
    ) -> EditorWorkbenchState {
        let group = EditorGroupState(id: .makeUnique(), tabs: tabs, activeSessionID: active)
        return EditorWorkbenchState(groups: [group], activeGroupID: group.id)
    }

    @Test("tabItems 保留顺序并标准化 URI，跳过无 URI 的 session")
    func tabItemsPreserveOrderAndStandardize() {
        let a = makeTab("00000000-0000-0000-0000-000000000001", path: "/tmp/Project/Sources/Main.swift")
        let b = makeTab("00000000-0000-0000-0000-000000000002", path: "/tmp/Project/Sources/Helper.swift")
        let untitled = makeTab("00000000-0000-0000-0000-000000000003", path: nil)

        let items = ProjectFilesState.tabItems(from: makeWorkbench([a, b, untitled], active: a.id))

        #expect(items.count == 2)
        #expect(items.map { $0.uri.path } == [
            "/tmp/Project/Sources/Main.swift",
            "/tmp/Project/Sources/Helper.swift"
        ])
        #expect(items[0].id == a.id)
    }

    @Test("activeFileURL 取激活标签的标准化 URI")
    func activeFileURLFromActiveTab() {
        let a = makeTab("00000000-0000-0000-0000-000000000001", path: "/tmp/Project/Sources/Main.swift")
        let b = makeTab("00000000-0000-0000-0000-000000000002", path: "/tmp/Project/Sources/Helper.swift")

        #expect(ProjectFilesState.activeFileURL(from: makeWorkbench([a, b], active: b.id))?.path
            == "/tmp/Project/Sources/Helper.swift")
        let noneActive = ProjectFilesState.activeFileURL(from: makeWorkbench([a, b], active: nil))
        #expect(noneActive == nil)
    }

    @Test("dirty 状态透传到 TabItem")
    func dirtyFlagPassesThrough() {
        let a = makeTab("00000000-0000-0000-0000-000000000001", path: "/tmp/a.swift", isDirty: true)
        let items = ProjectFilesState.tabItems(from: makeWorkbench([a], active: a.id))
        #expect(items.first?.isDirty == true)
    }
}
