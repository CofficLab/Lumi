import Foundation
import Testing
@testable import EditorLanguageRuntime

private func makeDescriptors() -> [EditorLanguageDescriptor] {
    [
        EditorLanguageDescriptor(
            languageId: "ruby", displayName: "Ruby", fileExtensions: ["rb"],
            shebangAliases: ["ruby"],
            highlightLanguageId: "ruby", lspLanguageId: "ruby"
        ),
        EditorLanguageDescriptor(
            languageId: "python", displayName: "Python", fileExtensions: ["py"],
            shebangAliases: ["python", "python3"],
            highlightLanguageId: "python", lspLanguageId: "python"
        ),
    ]
}

struct LanguageDetectionTests {
    @Test func urlExtensionWinsFirst() {
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/x.rb"),
            prefixBuffer: "#!/usr/bin/env python3"
        )
        #expect(ctx.languageId == "ruby")
    }

    @Test func unknownExtensionFallsBackToShebang() {
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/script.zzz"),
            prefixBuffer: "#!/usr/bin/env python3\nprint(1)"
        )
        #expect(ctx.languageId == "python")
    }

    @Test func shebangAliasWithVersionSuffix() {
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/noext"),
            prefixBuffer: "#!/usr/bin/env ruby"
        )
        #expect(ctx.languageId == "ruby")
    }

    @Test func modelineVimStyle() {
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/noext2"),
            prefixBuffer: "# comment\n# vim: set ft=ruby:\n",
            suffixBuffer: nil
        )
        #expect(ctx.languageId == "ruby")
    }

    @Test func modelineEmacsStyleFromSuffix() {
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/noext3"),
            prefixBuffer: "x = 1\n",
            suffixBuffer: "# -*- mode: python; -*-\n"
        )
        #expect(ctx.languageId == "python")
    }

    @Test func noSignalsYieldsPlainText() {
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/README.zzz"),
            prefixBuffer: "just text"
        )
        #expect(ctx.languageId == "plaintext")
    }

    @Test func extensionMatchIsCaseInsensitiveOnFileExtension() {
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/X.RB")
        )
        #expect(ctx.languageId == "ruby")
    }
}
