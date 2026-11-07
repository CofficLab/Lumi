import Combine
import SwiftUI
import Testing
@testable import PluginLogoManager
import ProviderLogo

@MainActor
@Suite("LogoManager Tests")
struct LogoManagerTests {

    @Test("注册 Logo 项后 allLogoItems 按 order 降序排列")
    func registerAndSort() {
        let manager = LogoManager()

        manager.registerLogoItem(LogoItem(id: "low", order: 100) { _ in EmptyView() })
        manager.registerLogoItem(LogoItem(id: "high", order: 300) { _ in EmptyView() })
        manager.registerLogoItem(LogoItem(id: "mid", order: 200) { _ in EmptyView() })

        #expect(manager.allLogoItems.count == 3)
        #expect(manager.allLogoItems.map(\.id) == ["high", "mid", "low"])
    }

    @Test("同 id 覆盖已有项")
    func registerOverwrite() {
        let manager = LogoManager()

        manager.registerLogoItem(LogoItem(id: "item", order: 100) { _ in EmptyView() })
        manager.registerLogoItem(LogoItem(id: "item", order: 500) { _ in EmptyView() })

        #expect(manager.allLogoItems.count == 1)
        #expect(manager.allLogoItems.first?.order == 500)
    }

    @Test("注销 Logo 项")
    func unregister() {
        let manager = LogoManager()

        manager.registerLogoItem(LogoItem(id: "a", order: 100) { _ in EmptyView() })
        manager.registerLogoItem(LogoItem(id: "b", order: 200) { _ in EmptyView() })
        manager.unregisterLogoItem(id: "a")

        #expect(manager.allLogoItems.count == 1)
        #expect(manager.allLogoItems.first?.id == "b")
    }

    @Test("清空所有贡献")
    func clearAll() {
        let manager = LogoManager()

        manager.registerLogoItem(LogoItem(id: "a", order: 100) { _ in EmptyView() })
        manager.registerLogoItem(LogoItem(id: "b", order: 200) { _ in EmptyView() })
        manager.clearAllContributions()

        #expect(manager.allLogoItems.isEmpty)
    }

    @Test("高亮状态切换")
    func highlightToggle() {
        let manager = LogoManager()

        #expect(manager.isLogoHighlighted == false)
        manager.setLogoHighlighted(true)
        #expect(manager.isLogoHighlighted == true)
        // 重复设置不触发变更（通过 guard 跳过）
        manager.setLogoHighlighted(true)
        #expect(manager.isLogoHighlighted == true)
        manager.setLogoHighlighted(false)
        #expect(manager.isLogoHighlighted == false)
    }

    @Test("状态变化通过 objectWillChange 通知菜单栏宿主重绘")
    func stateChangesPublishObjectWillChange() {
        let manager = LogoManager()
        var notifications = 0
        // 宿主 `ProviderRefreshModel` 依赖这个具体 publisher 类型做类型转换。
        let cancellable = manager.objectWillChange.sink { _ in notifications &+= 1 }

        manager.registerLogoItem(LogoItem(id: "a", order: 100) { _ in EmptyView() })
        #expect(notifications == 1)

        manager.setLogoHighlighted(true)
        #expect(notifications == 2)

        // 重复设置相同状态不改变数据，也不应触发重绘。
        manager.setLogoHighlighted(true)
        #expect(notifications == 2)

        manager.setLogoHighlighted(false)
        #expect(notifications == 3)

        cancellable.cancel()
    }
}
