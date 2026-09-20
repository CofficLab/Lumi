import Foundation
import EditorLanguageRuntime

public protocol SuperEditorLanguageGrammarProvider: LanguageGrammarProviding {}

extension BundledGrammarProvider: SuperEditorLanguageGrammarProvider {}

