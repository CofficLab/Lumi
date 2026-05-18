import Foundation

public extension LumiPreviewFacade {
    struct ModuleImportEligibilityChecker: Sendable {
        public init() {}

        public func shouldUseModuleImport(
            discovery: LumiPreviewFacade.PreviewDiscovery
        ) -> Bool {
            guard let bodySource = discovery.bodySource,
                  !bodySource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }

            let sourceText: String
            if let inMemory = discovery.sourceText {
                sourceText = inMemory
            } else if let loaded = try? String(contentsOf: discovery.sourceFileURL, encoding: .utf8) {
                sourceText = loaded
            } else {
                return true
            }

            let privateSymbols = privateOrFileprivateSymbols(in: sourceText)
            let privateExtensionMembers = privateOrFileprivateExtensionMembers(in: sourceText)
            guard !privateSymbols.isEmpty else {
                guard !bodyReferencesSymbols(bodySource, symbols: privateExtensionMembers, allowMemberAccess: true) else {
                    return false
                }
            return !bodyConstructsTypesWithPrivateInitializer(
                bodySource,
                typeNames: typesWithOnlyPrivateInitializers(in: sourceText)
            )
            }

            guard !bodyReferencesSymbols(bodySource, symbols: privateSymbols, allowMemberAccess: false) else {
                return false
            }

            guard !bodyReferencesSymbols(bodySource, symbols: privateExtensionMembers, allowMemberAccess: true) else {
                return false
            }

            return !bodyConstructsTypesWithPrivateInitializer(
                bodySource,
                typeNames: typesWithOnlyPrivateInitializers(in: sourceText)
            )
        }

        private func privateOrFileprivateSymbols(in sourceText: String) -> Set<String> {
            let patterns = [
                #"(?:^|\n)\s*(?:private|fileprivate)\s+(?:final\s+)?(?:class|struct|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
                #"(?:^|\n)\s*(?:private|fileprivate)\s+(?:static\s+|class\s+)?(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
                #"(?:^|\n)\s*(?:private|fileprivate)\s+func\s+([A-Za-z_][A-Za-z0-9_]*)"#,
                #"(?:^|\n)\s*(?:private|fileprivate)\s+typealias\s+([A-Za-z_][A-Za-z0-9_]*)"#
            ]

            var symbols = Set<String>()
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                    continue
                }
                let range = NSRange(sourceText.startIndex..<sourceText.endIndex, in: sourceText)
                for match in regex.matches(in: sourceText, options: [], range: range) {
                    guard match.numberOfRanges > 1,
                          let captureRange = Range(match.range(at: 1), in: sourceText) else {
                        continue
                    }
                    symbols.insert(String(sourceText[captureRange]))
                }
            }

            return symbols
        }

        private func bodyReferencesSymbols(
            _ bodySource: String,
            symbols: Set<String>,
            allowMemberAccess: Bool
        ) -> Bool {
            for symbol in symbols {
                let leadingBoundary = allowMemberAccess ? #"(?<![A-Za-z0-9_])"# : #"(?<![A-Za-z0-9_\.])"#
                let pattern = #"\#(leadingBoundary)\#(symbol)(?![A-Za-z0-9_])"#
                if bodySource.range(of: pattern, options: .regularExpression) != nil {
                    return true
                }
            }
            return false
        }

        private func typesWithOnlyPrivateInitializers(in sourceText: String) -> Set<String> {
            let typePattern = #"(?:^|\n)\s*(?:public|internal|package)?\s*(?:final\s+)?(?:class|struct|actor)\s+([A-Za-z_][A-Za-z0-9_]*)"# 
            guard let typeRegex = try? NSRegularExpression(pattern: typePattern, options: []) else {
                return []
            }

            let fullRange = NSRange(sourceText.startIndex..<sourceText.endIndex, in: sourceText)
            let typeMatches = typeRegex.matches(in: sourceText, options: [], range: fullRange)
            var matchingTypes = Set<String>()

            for match in typeMatches {
                guard match.numberOfRanges > 1,
                      let typeRange = Range(match.range(at: 1), in: sourceText) else {
                    continue
                }
                let typeName = String(sourceText[typeRange])
                guard let body = typeBody(
                    in: sourceText,
                    declarationRange: match.range
                ) else {
                    continue
                }

                let hasPrivateInitializer = body.range(
                    of: #"(?:^|\n)\s*(?:private|fileprivate)\s+init\s*\("#,
                    options: .regularExpression
                ) != nil
                let hasAccessibleInitializer = body.range(
                    of: #"(?:^|\n)\s*(?:(?:public|internal|package)\s+)?init\s*\("#,
                    options: .regularExpression
                ) != nil

                if hasPrivateInitializer && !hasAccessibleInitializer {
                    matchingTypes.insert(typeName)
                }
            }

            return matchingTypes
        }

        private func typeBody(
            in sourceText: String,
            declarationRange: NSRange
        ) -> String? {
            guard let declarationStart = Range(declarationRange, in: sourceText)?.lowerBound else {
                return nil
            }
            guard let openBrace = sourceText[declarationStart...].firstIndex(of: "{") else {
                return nil
            }

            var depth = 0
            var index = openBrace
            while index < sourceText.endIndex {
                let character = sourceText[index]
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(sourceText[sourceText.index(after: openBrace)..<index])
                    }
                }
                index = sourceText.index(after: index)
            }

            return nil
        }

        private func bodyConstructsTypesWithPrivateInitializer(
            _ bodySource: String,
            typeNames: Set<String>
        ) -> Bool {
            for typeName in typeNames {
                let pattern = #"(?<![A-Za-z0-9_])\#(typeName)\s*\("#
                if bodySource.range(of: pattern, options: .regularExpression) != nil {
                    return true
                }
            }
            return false
        }

        private func privateOrFileprivateExtensionMembers(
            in sourceText: String
        ) -> Set<String> {
            let extensionPattern = #"(?:^|\n)\s*(?:private|fileprivate)\s+extension\s+[A-Za-z_][A-Za-z0-9_]*(?:\s*:\s*[^{]+)?\s*\{"#
            guard let extensionRegex = try? NSRegularExpression(pattern: extensionPattern, options: []) else {
                return []
            }

            let fullRange = NSRange(sourceText.startIndex..<sourceText.endIndex, in: sourceText)
            let matches = extensionRegex.matches(in: sourceText, options: [], range: fullRange)
            var symbols = Set<String>()

            for match in matches {
                guard let body = typeBody(in: sourceText, declarationRange: match.range) else {
                    continue
                }
                symbols.formUnion(memberSymbols(in: body))
            }

            return symbols
        }

        private func memberSymbols(in sourceText: String) -> Set<String> {
            let patterns = [
                #"(?:^|\n)\s*(?:static\s+|class\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)"#,
                #"(?:^|\n)\s*(?:static\s+|class\s+)?(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
                #"(?:^|\n)\s*subscript\s*\("#
            ]

            var symbols = Set<String>()
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                    continue
                }
                let range = NSRange(sourceText.startIndex..<sourceText.endIndex, in: sourceText)
                for match in regex.matches(in: sourceText, options: [], range: range) {
                    guard match.numberOfRanges > 1,
                          let captureRange = Range(match.range(at: 1), in: sourceText) else {
                        continue
                    }
                    symbols.insert(String(sourceText[captureRange]))
                }
            }
            return symbols
        }
    }
}
