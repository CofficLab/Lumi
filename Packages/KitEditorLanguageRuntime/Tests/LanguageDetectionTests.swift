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

    @Test func modelineDoesNotMatchKeyInsideWords() {
        // `soft=` must not be misparsed as `ft=` (classic vim modeline pitfall).
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/noext4"),
            prefixBuffer: "# vim: set soft=ruby sw=2\n",
            suffixBuffer: nil
        )
        #expect(ctx.languageId == "plaintext")

        let valid = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/noext5"),
            prefixBuffer: "# vim: set soft=ruby ft=ruby\n",
            suffixBuffer: nil
        )
        #expect(valid.languageId == "ruby")
    }

    @Test func fileNameMatchIsCaseInsensitive() {
        let descriptors = [
            EditorLanguageDescriptor(
                languageId: "make", displayName: "Make", fileExtensions: ["makefile"]
            )
        ]
        let ctx = LanguageDetection.detect(descriptors: descriptors, url: URL(fileURLWithPath: "/tmp/Makefile"))
        #expect(ctx.languageId == "make")
    }

    @Test func shebangMatchingIsCaseInsensitiveOnAliases() {
        let descriptors = [
            EditorLanguageDescriptor(
                languageId: "ruby", displayName: "Ruby", fileExtensions: ["rb"],
                shebangAliases: ["Ruby"]
            )
        ]
        let ctx = LanguageDetection.detect(
            descriptors: descriptors,
            url: URL(fileURLWithPath: "/tmp/noext6"),
            prefixBuffer: "#!/usr/bin/env ruby"
        )
        #expect(ctx.languageId == "ruby")
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

    @Test func shebangDoesNotMatchSubstringInsideTokens() {
        // Extension "h" must not match the "h" inside "#!/bin/bash".
        let cHeader = EditorLanguageDescriptor(
            languageId: "c", displayName: "C", fileExtensions: ["h"]
        )
        let ctx = LanguageDetection.detect(
            descriptors: [cHeader],
            url: URL(fileURLWithPath: "/tmp/noext7"),
            prefixBuffer: "#!/bin/bash\necho hi\n"
        )
        #expect(ctx.languageId == "plaintext")

        // Alias "sh" must not match "#!/usr/bin/zsh".
        let shell = EditorLanguageDescriptor(
            languageId: "shell", displayName: "Shell", fileExtensions: ["sh"],
            shebangAliases: ["sh"]
        )
        let ctx2 = LanguageDetection.detect(
            descriptors: [shell],
            url: URL(fileURLWithPath: "/tmp/noext8"),
            prefixBuffer: "#!/usr/bin/zsh\n"
        )
        #expect(ctx2.languageId == "plaintext")

        // Exact token match still works.
        let ctx3 = LanguageDetection.detect(
            descriptors: [shell],
            url: URL(fileURLWithPath: "/tmp/noext9"),
            prefixBuffer: "#!/bin/sh\n"
        )
        #expect(ctx3.languageId == "shell")
    }

    @Test func shebangMatchesVersionedInterpreter() {
        // "python" alias should match a versioned interpreter like python3.2.
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/noext10"),
            prefixBuffer: "#!/usr/bin/python3.2\n"
        )
        #expect(ctx.languageId == "python")

        // But not a name that merely shares a prefix with extra letters.
        let ctx2 = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/noext11"),
            prefixBuffer: "#!/usr/bin/pythonx\n"
        )
        #expect(ctx2.languageId == "plaintext")
    }

    @Test func modelineVimMarkerRequiresWordBoundary() {
        // "svim:" must not be treated as a vim modeline marker.
        let ctx = LanguageDetection.detect(
            descriptors: makeDescriptors(),
            url: URL(fileURLWithPath: "/tmp/noext12"),
            prefixBuffer: "# svim: set ft=ruby\n"
        )
        #expect(ctx.languageId == "plaintext")
    }
}
