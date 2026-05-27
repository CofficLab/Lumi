import Testing
@testable import PluginAppStoreConnect

struct PluginAppStoreConnectTests {
    @Test
    func pluginIdentityIsStable() {
        #expect(AppStoreConnectPlugin.id == "AppStoreConnect")
        #expect(AppStoreConnectPlugin.iconName == "bag")
    }

    @Test
    func imageAssetTemplateURLReplacesApplePlaceholders() {
        let asset = AppStoreImageAsset(
            templateURL: "https://is1-ssl.mzstatic.com/image/thumb/source/{w}x{h}bb.{f}"
        )

        #expect(asset.url(width: 64, height: 64)?.absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/source/64x64bb.png")
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(AppStoreConnectLocalization.bundle.url(forResource: "AppStoreConnect", withExtension: "xcstrings") != nil)
        #expect(AppStoreConnectLocalization.string("App Store").isEmpty == false)
    }
}
