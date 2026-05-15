import Foundation
import Testing
@testable import StringCatalogKit

struct StringCatalogParserTests {
    @Test
    func parsesSourceLanguageAndSortedEntries() throws {
        let catalog = try StringCatalogParser.parse(sampleCatalog, locale: Locale(identifier: "en"))

        #expect(catalog.sourceLanguage == "en")
        #expect(catalog.entries.map(\.key) == ["Build %@%@", "Connected", "Items Count", "Missing Translation", "Stale Key"])
        #expect(catalog.entries.first?.valuesByLanguage["en"]?.text == "Build %1$@ %2$@")
        #expect(catalog.entries.first?.valuesByLanguage["zh-Hans"]?.text == "Build %1$@/%2$@")
    }

    @Test
    func computesLanguageCompletion() throws {
        let catalog = try StringCatalogParser.parse(sampleCatalog, locale: Locale(identifier: "en"))

        let english = try #require(catalog.languages.first(where: { $0.id == "en" }))
        let simplifiedChinese = try #require(catalog.languages.first(where: { $0.id == "zh-Hans" }))
        let hongKongChinese = try #require(catalog.languages.first(where: { $0.id == "zh-HK" }))

        #expect(english.isSourceLanguage)
        #expect(english.translatedCount == 5)
        #expect(english.totalCount == 5)
        #expect(english.completion == 1)

        #expect(simplifiedChinese.translatedCount == 3)
        #expect(simplifiedChinese.totalCount == 5)
        #expect(simplifiedChinese.completion == 0.6)

        #expect(hongKongChinese.translatedCount == 1)
        #expect(hongKongChinese.totalCount == 5)
        #expect(hongKongChinese.completion == 0.2)
    }

    @Test
    func keepsSourceLanguageFirst() throws {
        let catalog = try StringCatalogParser.parse(sampleCatalog, locale: Locale(identifier: "en"))

        #expect(catalog.languages.first?.id == "en")
        #expect(catalog.languages.contains(where: { $0.id == "zh-Hans" }))
        #expect(catalog.languages.contains(where: { $0.id == "zh-HK" }))
    }

    @Test
    func includesSourceLanguageWhenNoLocalizationUsesIt() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {
            "Hello": {
              "localizations": {
                "fr": {
                  "stringUnit": {
                    "state": "translated",
                    "value": "Bonjour"
                  }
                }
              }
            }
          }
        }
        """, locale: Locale(identifier: "en"))

        #expect(catalog.languages.map(\.id).contains("en"))
        #expect(catalog.languages.first?.id == "en")
        #expect(catalog.languages.first?.translatedCount == 0)
    }

    @Test
    func preservesExtractionAndTranslationStates() throws {
        let catalog = try StringCatalogParser.parse(sampleCatalog, locale: Locale(identifier: "en"))
        let stale = try #require(catalog.entries.first(where: { $0.key == "Stale Key" }))

        #expect(stale.extractionState == "stale")
        #expect(stale.valuesByLanguage["en"]?.state == "translated")
        #expect(stale.valuesByLanguage["zh-Hans"]?.state == "new")
    }

    @Test
    func extractsFirstVariationValue() throws {
        let catalog = try StringCatalogParser.parse(sampleCatalog, locale: Locale(identifier: "en"))
        let entry = try #require(catalog.entries.first(where: { $0.key == "Items Count" }))

        #expect(entry.valuesByLanguage["en"]?.text == "%lld item")
        #expect(entry.valuesByLanguage["zh-Hans"]?.text == "%lld 项")
        #expect(entry.valuesByLanguage["en"]?.state == "translated")
    }

    @Test
    func parsesEmptyCatalog() throws {
        let catalog = try StringCatalogParser.parse("""
        {
          "sourceLanguage": "en",
          "strings": {}
        }
        """, locale: Locale(identifier: "en"))

        #expect(catalog.entries.isEmpty)
        #expect(catalog.languages.count == 1)
        #expect(catalog.languages[0].id == "en")
        #expect(catalog.languages[0].completion == 0)
    }

    @Test
    func throwsForInvalidJSON() {
        #expect(throws: Error.self) {
            _ = try StringCatalogParser.parse("{", locale: Locale(identifier: "en"))
        }
    }
}

private let sampleCatalog = """
{
  "sourceLanguage": "en",
  "strings": {
    "Connected": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Connected"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "已连接"
          }
        },
        "zh-HK": {
          "stringUnit": {
            "state": "translated",
            "value": "已連接"
          }
        }
      }
    },
    "Build %@%@": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Build %1$@ %2$@"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "Build %1$@/%2$@"
          }
        }
      }
    },
    "Missing Translation": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Missing Translation"
          }
        }
      }
    },
    "Stale Key": {
      "extractionState": "stale",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Stale Key"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "new",
            "value": ""
          }
        }
      }
    },
    "Items Count": {
      "localizations": {
        "en": {
          "variations": {
            "plural": {
              "one": {
                "stringUnit": {
                  "state": "translated",
                  "value": "%lld item"
                }
              },
              "other": {
                "stringUnit": {
                  "state": "translated",
                  "value": "%lld items"
                }
              }
            }
          }
        },
        "zh-Hans": {
          "variations": {
            "plural": {
              "other": {
                "stringUnit": {
                  "state": "translated",
                  "value": "%lld 项"
                }
              }
            }
          }
        }
      }
    }
  }
}
"""
