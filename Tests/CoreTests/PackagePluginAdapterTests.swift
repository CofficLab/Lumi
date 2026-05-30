#if canImport(XCTest)
import EditorService
import PluginThemeSky
import XCTest
@testable import Lumi

final class PackagePluginAdapterTests: XCTestCase {
    @MainActor
    func testPackagePluginAdapterDispatchesEditorExtensionRegistration() {
        let registry = EditorExtensionRegistry()
        let adapter = PackagePluginAdapter<ThemeSkyPlugin>.shared

        adapter.registerEditorExtensions(into: registry)

        XCTAssertNotNil(registry.theme(for: "sky-dark"))
        XCTAssertNotNil(registry.theme(for: "sky-light"))
    }
}
#endif
