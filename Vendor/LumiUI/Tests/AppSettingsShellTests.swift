import Testing
@testable import LumiUI

struct AppBundleInfoTests {
    @Test
    func readsNameFromBundle() {
        let info = AppBundleInfo(bundle: .main)
        #expect(!info.name.isEmpty)
        #expect(!info.bundleIdentifier.isEmpty)
    }
}
