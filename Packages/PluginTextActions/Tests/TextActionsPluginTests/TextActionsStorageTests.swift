import Foundation
import Testing
@testable import TextActionsPlugin

// MARK: - 临时目录助手

/// 为每个用例提供独立的临时目录。
private struct TempDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextActionsTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - 运行时目录

@Suite("Text Actions 运行时目录", .serialized)
@MainActor
struct TextActionsRuntimeTests {

    @Test("注入目录后 settingsDirectory 返回该目录")
    func usesConfiguredDirectory() {
        let temp = TempDirectory()
        defer {
            TextActionsRuntime.reset()
            temp.cleanup()
        }

        TextActionsRuntime.configure(settingsDirectory: temp.url)

        #expect(TextActionsRuntime.settingsDirectory() == temp.url)
    }

    @Test("重置后回到默认回退目录")
    func resetsToFallbackDirectory() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        TextActionsRuntime.configure(settingsDirectory: temp.url)

        TextActionsRuntime.reset()

        let path = TextActionsRuntime.settingsDirectory().path
        #expect(path.hasSuffix("com.coffic.lumi.plugin.text-actions"))
        #expect(path.contains("com.coffic.Lumi"))
    }
}

// MARK: - 本地存储

@Suite("Text Actions 本地存储")
struct TextActionsPluginLocalStoreTests {

    @Test("写入后能读回同一个值")
    func roundTripsValue() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url)

        store.set(true, forKey: "flag")

        #expect(store.object(forKey: "flag") as? Bool == true)
        #expect(store.bool(forKey: "flag"))
    }

    @Test("写入 nil 会移除该键")
    func removingValue() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url)
        store.set(true, forKey: "flag")

        store.set(nil, forKey: "flag")

        #expect(store.object(forKey: "flag") == nil)
        #expect(store.bool(forKey: "flag") == false)
    }

    @Test("未写入的键读回 nil 与 false")
    func missingKeyReadsAsEmpty() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url)

        #expect(store.object(forKey: "absent") == nil)
        #expect(store.bool(forKey: "absent") == false)
    }

    @Test("非布尔值按 false 处理")
    func nonBooleanReadsAsFalse() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url)

        store.set("not a bool", forKey: "text")

        #expect(store.object(forKey: "text") as? String == "not a bool")
        #expect(store.bool(forKey: "text") == false)
    }

    @Test("启用开关可读写")
    func enabledSwitchRoundTrips() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url)

        store.setEnabled(true)
        #expect(store.isEnabled)

        store.setEnabled(false)
        #expect(store.isEnabled == false)
    }

    @Test("存储落在 settings.plist 且能被新实例读回")
    func persistsAcrossInstances() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url)
        store.setEnabled(true)

        #expect(FileManager.default.fileExists(atPath: temp.url.appendingPathComponent("settings.plist").path))

        let reloaded = TextActionsPluginLocalStore(settingsDirectory: temp.url)
        #expect(reloaded.isEnabled)
    }

    @Test("损坏的 plist 被当作空字典")
    func treatsCorruptFileAsEmpty() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let file = temp.url.appendingPathComponent("settings.plist")
        try? Data("not a plist".utf8).write(to: file)

        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url)

        #expect(store.object(forKey: "any") == nil)
        #expect(store.isEnabled == false)
    }

    @Test("不同实例使用各自隔离的目录")
    func isolatesInstancesByDirectory() {
        let first = TempDirectory()
        let second = TempDirectory()
        defer {
            first.cleanup()
            second.cleanup()
        }
        let storeA = TextActionsPluginLocalStore(settingsDirectory: first.url)
        let storeB = TextActionsPluginLocalStore(settingsDirectory: second.url)
        storeA.setEnabled(true)

        #expect(storeA.isEnabled)
        #expect(storeB.isEnabled == false)
    }
}
