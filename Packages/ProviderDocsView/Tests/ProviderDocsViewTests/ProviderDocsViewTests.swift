import SwiftUI
import Testing
@testable import ProviderDocsView

/// DocsViewProviding 协议与默认实现的基础验证。
@Suite("ProviderDocsView")
@MainActor
struct ProviderDocsViewTests {

    @Test("初始条目为空")
    func defaultProviderStartsEmpty() {
        let provider = DefaultDocsViewProviding()

        #expect(provider.aboutEntries.isEmpty)
        #expect(provider.manualEntries.isEmpty)
    }

    @Test("追加条目后可读取")
    func defaultProviderStoresEntries() {
        let provider = DefaultDocsViewProviding()
        provider.addAbout(DocsEntry(id: "device", name: "设备信息") { Text("about") })
        provider.addManual(DocsEntry(id: "device", name: "设备信息") { Text("manual") })

        #expect(provider.aboutEntries.count == 1)
        #expect(provider.aboutEntries[0].id == "device")
        #expect(provider.aboutEntries[0].name == "设备信息")
        #expect(provider.manualEntries.count == 1)
        #expect(type(of: provider.aboutEntries[0].makeView()) == AnyView.self)
        #expect(type(of: provider.manualEntries[0].makeView()) == AnyView.self)
    }

    @Test("同 id 追加去重")
    func defaultProviderDeduplicatesEntries() {
        let provider = DefaultDocsViewProviding()
        provider.addAbout(DocsEntry(id: "a", name: "A") { Text("a1") })
        provider.addAbout(DocsEntry(id: "a", name: "A") { Text("a2") })
        provider.addManual(DocsEntry(id: "b", name: "B") { Text("b1") })
        provider.addManual(DocsEntry(id: "b", name: "B") { Text("b2") })

        #expect(provider.aboutEntries.count == 1)
        #expect(provider.manualEntries.count == 1)
    }

    @Test("DocsViewProviding 可作为 any DocsViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any DocsViewProviding = DefaultDocsViewProviding()
        provider.addAbout(DocsEntry(id: "device", name: "设备信息") { Text("about") })
        provider.addManual(DocsEntry(id: "device", name: "设备信息") { Text("manual") })

        #expect(provider.aboutEntries.count == 1)
        #expect(provider.manualEntries.count == 1)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomDocsView: DocsViewProviding {
            var aboutEntries: [DocsEntry] = []
            var manualEntries: [DocsEntry] = []

            func replaceAboutEntries(_ entries: [DocsEntry]) {
                aboutEntries = entries
            }

            func replaceManualEntries(_ entries: [DocsEntry]) {
                manualEntries = entries
            }
        }

        let provider: any DocsViewProviding = CustomDocsView()
        provider.addAbout(DocsEntry(id: "a", name: "A") { Text("about") })
        provider.addManual(DocsEntry(id: "a", name: "A") { Text("manual") })

        #expect(provider.aboutEntries.count == 1)
        #expect(provider.manualEntries.count == 1)
    }
}
