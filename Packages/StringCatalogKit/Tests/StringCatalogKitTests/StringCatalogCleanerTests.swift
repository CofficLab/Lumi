import Foundation
import Testing
@testable import StringCatalogKit

struct StringCatalogCleanerTests {
    @Test
    func removesStaleEntries() throws {
        let result = try StringCatalogCleaner.removingStaleEntries(from: """
        {
          "sourceLanguage": "en",
          "strings": {
            "Active": {
              "extractionState": "stale",
              "localizations": {
                "en": {
                  "stringUnit": {
                    "state": "translated",
                    "value": "Active"
                  }
                }
              }
            },
            "Connected": {
              "localizations": {
                "en": {
                  "stringUnit": {
                    "state": "translated",
                    "value": "Connected"
                  }
                }
              }
            }
          }
        }
        """)

        let catalog = try StringCatalogParser.parse(result.source, locale: Locale(identifier: "en"))
        #expect(result.removedCount == 1)
        #expect(catalog.entries.map(\.key) == ["Connected"])
    }

    @Test
    func leavesCatalogUnchangedWhenNoStaleEntriesExist() throws {
        let source = """
        {
          "sourceLanguage": "en",
          "strings": {
            "Connected": {}
          }
        }
        """
        let result = try StringCatalogCleaner.removingStaleEntries(from: source)

        #expect(result.removedCount == 0)
        #expect(result.source == source)
    }

    @Test
    func ignoresMalformedCatalogShape() throws {
        let source = """
        {
          "sourceLanguage": "en"
        }
        """
        let result = try StringCatalogCleaner.removingStaleEntries(from: source)

        #expect(result.removedCount == 0)
        #expect(result.source == source)
    }
}
