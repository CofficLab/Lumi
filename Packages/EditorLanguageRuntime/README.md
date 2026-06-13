# EditorLanguageRuntime

Language-agnostic tree-sitter runtime for the Lumi editor.

- `EditorLanguageDescriptor` / `EditorLanguageContext` — language metadata
- `LanguageRegistry` — populated by language plugins at startup
- `BundledGrammarProvider` — reusable grammar + `.scm` query loader
- `LanguageDetection` — extension / shebang / modeline detection

Syntax grammars and highlight queries live in **language plugins** under `Plugins/Editor*Plugin/`.
