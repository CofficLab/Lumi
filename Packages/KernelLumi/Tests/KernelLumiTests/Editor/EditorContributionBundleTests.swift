import Foundation
import Testing

@testable import KernelLumi

/// `EditorContributionBundle` 契约测试（§21.1：selector、bundle 原子替换校验）。
@Suite("Editor Contribution Bundle")
struct EditorContributionBundleTests {
    private func makeBundle(
        pluginID: String = "test.plugin",
        languages: [EditorLanguageContribution] = [],
        apiVersion: EditorPluginAPIVersion = .current
    ) -> EditorContributionBundle {
        EditorContributionBundle(
            pluginID: pluginID,
            apiVersion: apiVersion,
            languages: languages
        )
    }

    private func makeLanguage(_ id: String) -> EditorLanguageContribution {
        EditorLanguageContribution(
            language: EditorLanguageDescriptor(
                languageId: id,
                displayName: id,
                fileExtensions: [id]
            )
        )
    }

    @Test("盖戳覆盖插件自报的 pluginID 与 generation")
    func stamping() {
        let stamped = makeBundle(pluginID: "self-reported").stamped(pluginID: "trusted.id", generation: 42)
        #expect(stamped.pluginID == "trusted.id")
        #expect(stamped.generation == 42)
    }

    @Test("内部一致性校验：重复语言/命令 id 与空 id 报错")
    func validationIssues() {
        #expect(makeBundle(languages: [makeLanguage("a"), makeLanguage("a")]).validationIssues.isEmpty == false)
        #expect(makeBundle(languages: [makeLanguage("")]).validationIssues.isEmpty == false)
        #expect(makeBundle(languages: [makeLanguage("a")]).validationIssues.isEmpty)
    }

    @Test("API 版本兼容判定")
    func apiCompatibility() {
        #expect(makeBundle().isCompatible(with: .current))
        #expect(makeBundle(apiVersion: .init(major: 99, minor: 0)).isCompatible(with: .current) == false)
    }
}

/// `EditorFeatureProvider` 基协议的解析测试用 Provider。
private final class TestProvider: EditorFeatureProvider {
    let id = "test.provider"
    let selector = EditorDocumentSelector(languageID: "swift")
}

@Suite("Editor Feature Provider")
struct EditorFeatureProviderTests {
    @Test("基协议默认值与 selector 传递")
    func defaultsAndSelector() {
        let provider = TestProvider()
        #expect(provider.priority == 0)
        #expect(provider.requiredTrust == .none)
        #expect(provider.selector.matches(.init(
            id: .makeUnique(),
            uri: URL(fileURLWithPath: "/tmp/A.swift"),
            languageID: "swift",
            revision: 1,
            isDirty: false,
            isReadOnly: false,
            largeFileMode: .normal
        )))
    }
}
