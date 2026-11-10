import SwiftUI
import Testing
@testable import ProviderDocsView

/// DocsViewProviding 全量替换、跨表移除与追加去重的契约测试。
@Suite("ProviderDocsView mutations")
@MainActor
struct ProviderDocsViewMutationTests {

    private func entry(id: String, name: String = "Entry") -> DocsEntry {
        DocsEntry(id: id, name: name) { Text("content-\(id)") }
    }

    @Test("removeEntries 同时移除关于与说明书条目")
    func removeEntriesClearsBothTables() {
        let provider = DefaultDocsViewProviding()
        provider.addAbout(entry(id: "a"))
        provider.addAbout(entry(id: "b"))
        provider.addManual(entry(id: "a"))
        provider.addManual(entry(id: "c"))

        provider.removeEntries(id: "a")

        #expect(provider.aboutEntries.map(\.id) == ["b"])
        #expect(provider.manualEntries.map(\.id) == ["c"])
    }

    @Test("removeEntries 只移除目标插件的条目")
    func removeEntriesIsSelective() {
        let provider = DefaultDocsViewProviding()
        provider.addAbout(entry(id: "com.one"))
        provider.addAbout(entry(id: "com.two"))
        provider.addManual(entry(id: "com.one"))

        provider.removeEntries(id: "com.one")

        #expect(provider.aboutEntries.map(\.id) == ["com.two"])
        #expect(provider.manualEntries.isEmpty)
    }

    @Test("removeEntries 对未知 id 为 no-op")
    func removeEntriesUnknownIsNoop() {
        let provider = DefaultDocsViewProviding()
        provider.addAbout(entry(id: "a"))

        provider.removeEntries(id: "missing")

        #expect(provider.aboutEntries.map(\.id) == ["a"])
    }

    @Test("replaceAboutEntries 全量替换并发布事件")
    func replaceAboutReplacesAndNotifies() {
        let provider = DefaultDocsViewProviding()
        provider.addAbout(entry(id: "a"))
        var aboutEvents = 0
        let handle = provider.addDocsViewObserver { event in
            if case .aboutEntriesChanged = event { aboutEvents += 1 }
        }

        provider.replaceAboutEntries([entry(id: "x"), entry(id: "y")])

        #expect(provider.aboutEntries.map(\.id) == ["x", "y"])
        #expect(aboutEvents == 1)
        handle.cancel()
    }

    @Test("replaceManualEntries 不影响关于条目")
    func replaceManualLeavesAboutIntact() {
        let provider = DefaultDocsViewProviding()
        provider.addAbout(entry(id: "about"))

        provider.replaceManualEntries([entry(id: "manual")])

        #expect(provider.aboutEntries.map(\.id) == ["about"])
        #expect(provider.manualEntries.map(\.id) == ["manual"])
    }

    @Test("同 id 追加保留先注册条目")
    func duplicateAddKeepsFirstEntry() {
        let provider = DefaultDocsViewProviding()
        provider.addAbout(entry(id: "a", name: "First"))
        provider.addAbout(entry(id: "a", name: "Second"))

        #expect(provider.aboutEntries.count == 1)
        #expect(provider.aboutEntries[0].name == "First")
    }

    @Test("observer 取消后替换不再通知")
    func cancelledObserverStopsReplaceNotifications() {
        let provider = DefaultDocsViewProviding()
        var manualEvents = 0
        let handle = provider.addDocsViewObserver { event in
            if case .manualEntriesChanged = event { manualEvents += 1 }
        }

        provider.replaceManualEntries([entry(id: "m")])
        #expect(manualEvents == 1)

        handle.cancel()
        provider.replaceManualEntries([entry(id: "m2")])
        #expect(manualEvents == 1)
    }
}
