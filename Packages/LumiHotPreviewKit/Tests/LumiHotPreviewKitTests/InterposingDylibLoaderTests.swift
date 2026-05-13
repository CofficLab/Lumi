import Foundation
import Testing
@testable import LumiHotPreviewKit

@Suite("InterposingDylibLoader")
struct InterposingDylibLoaderTests {
    @Test("returns missing dylib error for nonexistent path")
    func returnsMissingDylibErrorForNonexistentPath() async {
        let loader = LumiHotPreviewPackage.InterposingDylibLoader()

        await #expect(throws: LumiHotPreviewPackage.InterposingDylibLoader.LoaderError.missingDylib(
            path: "/tmp/DefinitelyMissing.dylib"
        )) {
            try await loader.load(dylibPath: "/tmp/DefinitelyMissing.dylib")
        }
    }

    @Test("resolves a known symbol from a system dylib")
    func resolvesKnownSymbolFromSystemDylib() async throws {
        let loader = LumiHotPreviewPackage.InterposingDylibLoader()
        let dylibPath = "/usr/lib/libobjc-trampolines.dylib"

        let loaded = try await loader.load(dylibPath: dylibPath)

        #expect(loaded.path == dylibPath)
        #expect(loaded.symbolName == nil)
        #expect(!(try await loader.resolveSymbol(named: "__definitely_missing_symbol__", in: dylibPath)))
        await loader.unloadAll()
    }
}
