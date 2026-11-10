import AppKit
import Testing
@testable import NettoPlugin

@MainActor
@Suite("Netto 运行应用列表")
struct NettoRunningAppsStoreTests {
    @Test("应用启动或退出后 refresh 会重新计算结果")
    func refreshRecomputesRunningApps() {
        final class Box {
            var apps: [SmartApp] = [
                SmartApp(id: "com.example.A", name: "A"),
                SmartApp(id: "com.example.B", name: "B"),
            ]
        }
        let box = Box()
        let store = NettoRunningAppsStore(load: { box.apps })

        #expect(store.apps.map(\.id) == ["com.example.A", "com.example.B"])

        // 模拟 A 退出、C 启动。
        box.apps = [
            SmartApp(id: "com.example.B", name: "B"),
            SmartApp(id: "com.example.C", name: "C"),
        ]
        store.refresh()

        #expect(store.apps.map(\.id) == ["com.example.B", "com.example.C"])
    }
}
