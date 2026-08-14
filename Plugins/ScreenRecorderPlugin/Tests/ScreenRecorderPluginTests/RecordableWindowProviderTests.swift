import CoreGraphics
import Foundation
import Testing
@testable import ScreenRecorderPlugin

@Suite("RecordableWindowProvider.select")
struct RecordableWindowProviderTests {

    private func make(_ id: CGWindowID, _ bundle: String, _ name: String, _ title: String) -> RecordableWindow {
        RecordableWindow(id: id, processIdentifier: pid_t(id), bundleIdentifier: bundle, applicationName: name, windowTitle: title, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    @MainActor
    @Test("按应用名匹配返回首个")
    func matchByName() {
        let windows = [
            make(1, "com.apple.Maps", "Maps", "Maps"),
            make(2, "com.google.Maps", "Google Maps", "Search"),
        ]
        let r = RecordableWindowProvider.select(from: windows, application: "Maps", windowTitle: nil)
        #expect(r?.id == 1)
    }

    @MainActor
    @Test("按 bundleId 精确匹配")
    func matchByBundleId() {
        let windows = [
            make(1, "com.apple.Maps", "Maps", "Maps"),
            make(2, "com.google.Maps", "Google Maps", "Search"),
        ]
        let r = RecordableWindowProvider.select(from: windows, application: "com.google.Maps", windowTitle: nil)
        #expect(r?.id == 2)
    }

    @MainActor
    @Test("窗口标题子串进一步过滤")
    func matchByTitle() {
        let windows = [
            make(1, "com.apple.Maps", "Maps", "Maps"),
            make(2, "com.apple.Maps", "Maps", "Directions"),
        ]
        let r = RecordableWindowProvider.select(from: windows, application: "Maps", windowTitle: "directions")
        #expect(r?.windowTitle == "Directions")
    }

    @MainActor
    @Test("无匹配返回 nil")
    func noMatch() {
        let windows = [make(1, "com.apple.Maps", "Maps", "Maps")]
        let r = RecordableWindowProvider.select(from: windows, application: "Notepad", windowTitle: nil)
        #expect(r == nil)
    }
}
