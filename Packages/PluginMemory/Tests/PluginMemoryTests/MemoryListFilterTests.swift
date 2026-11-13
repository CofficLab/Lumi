import Foundation
import Testing
@testable import PluginMemory

/// 记忆列表过滤规则（见 issue #1304）。
///
/// 过滤原先内联在 `MemorySettingsView` 的 body 里，每次按键会被读 3~4 次，
/// 每次都全量过滤一遍列表。抽成纯函数后既可断言，又只算一次。
@Suite("记忆列表过滤")
struct MemoryListFilterTests {

    private func makeItem(
        id: String,
        type: MemoryType = .user,
        name: String = "name",
        description: String = "desc"
    ) -> MemoryItem {
        MemoryItem(
            id: id,
            type: type,
            name: name,
            description: description,
            content: "content",
            filePath: "/tmp/\(id)"
        )
    }

    @Test("无过滤条件时返回全部条目")
    func noFilterReturnsAllItems() {
        let items = [makeItem(id: "a"), makeItem(id: "b")]

        #expect(MemoryListFilter.filter(items, type: nil, query: "") .map(\.id) == items.map(\.id))
    }

    @Test("按类型过滤")
    func filtersByType() {
        let user = makeItem(id: "a", type: .user)
        let feedback = makeItem(id: "b", type: .feedback)
        let items = [user, feedback]

        #expect(MemoryListFilter.filter(items, type: .user, query: "") .map(\.id) == [user.id])
        #expect(MemoryListFilter.filter(items, type: .feedback, query: "") .map(\.id) == [feedback.id])
    }

    @Test("按查询词匹配名称、描述与 ID")
    func filtersByQueryAcrossFields() {
        let byName = makeItem(id: "a", name: "Alpha")
        let byDescription = makeItem(id: "b", description: "Beta notes")
        let byID = makeItem(id: "gamma-id")
        let items = [byName, byDescription, byID]

        #expect(MemoryListFilter.filter(items, type: nil, query: "alpha") .map(\.id) == [byName.id])
        #expect(MemoryListFilter.filter(items, type: nil, query: "beta") .map(\.id) == [byDescription.id])
        #expect(MemoryListFilter.filter(items, type: nil, query: "gamma") .map(\.id) == [byID.id])
    }

    @Test("查询词大小写不敏感")
    func queryIsCaseInsensitive() {
        let item = makeItem(id: "a", name: "Alpha")
        let items = [item]

        #expect(MemoryListFilter.filter(items, type: nil, query: "ALPHA").map(\.id) == [item.id])
    }

    @Test("类型与查询词同时生效")
    func typeAndQueryCombine() {
        let user = makeItem(id: "a", type: .user, name: "alpha")
        let feedback = makeItem(id: "b", type: .feedback, name: "alpha")
        let items = [user, feedback]

        #expect(MemoryListFilter.filter(items, type: .user, query: "alpha") .map(\.id) == [user.id])
        #expect(MemoryListFilter.filter(items, type: .feedback, query: "alpha") .map(\.id) == [feedback.id])
        #expect(MemoryListFilter.filter(items, type: .user, query: "beta").isEmpty)
    }

    @Test("无命中时返回空数组")
    func noMatchReturnsEmpty() {
        let items = [makeItem(id: "a", name: "Alpha")]

        #expect(MemoryListFilter.filter(items, type: nil, query: "zzz").isEmpty)
    }
}
