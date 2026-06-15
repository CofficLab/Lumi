import Foundation
import Testing
@testable import StringCatalogKit

struct StringCatalogTranslationIssuesTests {
    @Test
    func detectsUntranslatedEntries() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "Hello": {
              "localizations": {
                "en": {
                  "stringUnit": {
                    "state": "translated",
                    "value": "Hello"
                  }
                },
                "zh-Hans": {
                  "stringUnit": {
                    "state": "translated",
                    "value": "Hello"
                  }
                }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        let issues = catalog.translationIssues
        #expect(issues.totalCount == 1)
        #expect(issues.issues[0].key == "Hello")
        #expect(issues.issues[0].language == "zh-Hans")
        #expect(issues.issues[0].kind == .untranslated)
    }

    @Test
    func detectsMissingEntries() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "Hello": {
              "localizations": {
                "en": {
                  "stringUnit": {
                    "state": "translated",
                    "value": "Hello"
                  }
                }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        let issues = catalog.translationIssues
        #expect(issues.totalCount == 0)
    }

    @Test
    func detectsMixedIssues() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "OK": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "OK" } },
                "zh-Hans": { "stringUnit": { "state": "translated", "value": "OK" } }
              }
            },
            "Cancel": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Cancel" } },
                "zh-Hans": { "stringUnit": { "state": "translated", "value": "取消" } }
              }
            },
            "Save": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Save" } }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        let issues = catalog.translationIssues
        // "OK" is untranslated (zh-Hans value == key)
        // "Save" has no zh-Hans at all → but the test catalog only has "en" in languages
        // since no non-source language appears in any entry
        let untranslated = issues.issues.filter { $0.kind == .untranslated }
        #expect(untranslated.count == 1)
        #expect(untranslated[0].key == "OK")
        #expect(untranslated[0].language == "zh-Hans")
    }

    @Test
    func skipsStaleEntries() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "Old Key": {
              "extractionState": "stale",
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Old Key" } },
                "zh-Hans": { "stringUnit": { "state": "translated", "value": "Old Key" } }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        let issues = catalog.translationIssues
        #expect(issues.isEmpty)
    }

    @Test
    func returnsEmptyForFullyTranslated() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "Hello": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Hello" } },
                "zh-Hans": { "stringUnit": { "state": "translated", "value": "你好" } }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        #expect(catalog.translationIssues.isEmpty)
    }

    @Test
    func groupsByLanguage() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "A": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "A" } },
                "zh-Hans": { "stringUnit": { "state": "translated", "value": "A" } },
                "zh-Hant": { "stringUnit": { "state": "translated", "value": "A" } }
              }
            },
            "B": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "B" } },
                "zh-Hans": { "stringUnit": { "state": "translated", "value": "B" } },
                "zh-Hant": { "stringUnit": { "state": "translated", "value": "B" } }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        let counts = catalog.translationIssues.countByLanguage
        #expect(counts["zh-Hans"] == 2)
        #expect(counts["zh-Hant"] == 2)
    }

    @Test
    func ignoresEmptyTextValues() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "Empty": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Empty" } },
                "zh-Hans": { "stringUnit": { "state": "new", "value": "" } }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        // Empty text should not count as untranslated (value != key)
        let issues = catalog.translationIssues
        #expect(issues.isEmpty)
    }

    @Test
    func listsStaleEntryKeysSorted() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "Beta": {
              "extractionState": "stale",
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Beta" } }
              }
            },
            "Alpha": {
              "extractionState": "stale",
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Alpha" } }
              }
            },
            "Live": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Live" } }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        #expect(catalog.staleEntryKeys == ["Alpha", "Beta"])
        #expect(catalog.staleEntryCount == 2)
    }
}
