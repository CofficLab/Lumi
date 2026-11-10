import Foundation
import Testing

@Suite("Hydration 设置页布局")
struct HydrationSettingsLayoutTests {
    @Test("使用共享设置页布局与卡片组件")
    func usesSharedSettingsLayout() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot.appendingPathComponent(
            "Sources/PluginHydrationReminder/HydrationSettingsView.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("AppSettingsContentScaffold"))
        #expect(!source.contains("Form {"))
        #expect(!source.contains("Form("))
        #expect(!source.contains(".padding(18)"))
        #expect(!source.contains("GroupBox {"))

        for component in [
            "AppCard",
            "AppSettingsSection(",
            "AppSettingsRow(",
            "AppSettingsToggleRow(",
            "AppSettingsStepperRow(",
            "AppSettingsPickerRow(",
            "AppSettingsSegmentedPickerRow(",
            "AppSettingsReadOnlyRow(",
            "AppSettingsSecureFieldRow(",
        ] {
            #expect(!source.contains(component))
        }
    }
}
