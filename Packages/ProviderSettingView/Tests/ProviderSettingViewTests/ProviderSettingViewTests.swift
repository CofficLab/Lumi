import Combine
import SwiftUI
import Testing
@testable import ProviderSettingView

/// SettingViewProviding 协议、SettingEntryItem 模型与默认实现的基础验证。
@Suite("ProviderSettingView")
@MainActor
struct ProviderSettingViewTests {

    @Test("SettingEntryItem 可创建且携带入口信息")
    func entryItemBasics() {
        let entry = SettingEntryItem(id: "general", title: "General", systemImage: "gearshape") {
            Text("general detail")
        }

        #expect(entry.id == "general")
        #expect(entry.title == "General")
        #expect(entry.systemImage == "gearshape")
        #expect(entry.order == 200)
    }

    @Test("DefaultSettingViewProviding 注入入口后排序且默认选中第一个")
    func defaultProviderStoresSortsAndSelectsFirst() {
        let provider = DefaultSettingViewProviding()
        let entries = [
            SettingEntryItem(id: "b", title: "B", systemImage: "b", order: 200) { Text("B") },
            SettingEntryItem(id: "a", title: "A", systemImage: "a", order: 100) { Text("A") },
        ]

        provider.registerEntries(entries)

        #expect(provider.entries.count == 2)
        #expect(provider.entries.map(\.id) == ["a", "b"])
        #expect(provider.selectedEntryID == "a")
    }

    @Test("selectEntry 切换选中入口")
    func selectEntrySwitchesSelected() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([
            SettingEntryItem(id: "a", title: "A", systemImage: "a") { Text("A") },
            SettingEntryItem(id: "b", title: "B", systemImage: "b") { Text("B") },
        ])

        provider.selectEntry(id: "b")

        #expect(provider.selectedEntryID == "b")
    }

    @Test("注入入口后返回可渲染的设置视图")
    func defaultProviderRendersView() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([
            SettingEntryItem(id: "a", title: "A", systemImage: "folder") { Text("A detail") },
        ])

        #expect(type(of: provider.makeSettingView()) == AnyView.self)
    }

    @Test("无入口时返回可渲染的设置视图")
    func defaultProviderRendersEmptyView() {
        let provider = DefaultSettingViewProviding()

        #expect(type(of: provider.makeSettingView()) == AnyView.self)
    }

    @Test("SettingViewProviding 可作为 any SettingViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any SettingViewProviding = DefaultSettingViewProviding()
        provider.registerEntries([
            SettingEntryItem(id: "x", title: "X", systemImage: "xmark") { Text("X") },
        ])

        #expect(provider.entries.count == 1)
        #expect(type(of: provider.makeSettingView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        @MainActor final class CustomSettingView: SettingViewProviding {
            @Published var entries: [SettingEntryItem] = []

            func registerEntries(_ entries: [SettingEntryItem]) {
                self.entries = entries
            }

            func makeSettingView() -> AnyView {
                AnyView(Text("custom settings"))
            }
        }

        let provider: any SettingViewProviding = CustomSettingView()
        provider.registerEntries([
            SettingEntryItem(id: "y", title: "Y", systemImage: "ycircle") { Text("Y") },
        ])

        #expect(provider.entries.count == 1)
        #expect(type(of: provider.makeSettingView()) == AnyView.self)
    }
}
