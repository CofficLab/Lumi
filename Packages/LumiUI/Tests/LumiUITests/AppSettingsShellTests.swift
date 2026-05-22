import Testing
import ToolKit
@testable import LumiUI

struct AppBundleInfoTests {
    @Test
    func readsNameFromBundle() {
        let info = AppBundleInfo(bundle: .main)
        #expect(!info.name.isEmpty)
        #expect(!info.bundleIdentifier.isEmpty)
    }
}

struct CommandRiskLevelUITests {
    @Test
    func iconNamesAreNonEmpty() {
        #expect(CommandRiskLevel.safe.iconName.isEmpty == false)
        #expect(CommandRiskLevel.low.iconName.isEmpty == false)
        #expect(CommandRiskLevel.medium.iconName.isEmpty == false)
        #expect(CommandRiskLevel.high.iconName.isEmpty == false)
    }

    @Test
    func highRiskRequiresPermission() {
        #expect(CommandRiskLevel.high.requiresPermission)
        #expect(CommandRiskLevel.safe.requiresPermission == false)
    }
}
