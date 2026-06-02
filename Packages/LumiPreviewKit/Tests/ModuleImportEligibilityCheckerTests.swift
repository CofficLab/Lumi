import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("ModuleImportEligibilityChecker")
struct ModuleImportEligibilityCheckerTests {
    @Test("rejects module import using private symbols from UTF-16 source files")
    func rejectsModuleImportForPrivateSymbolsInUTF16SourceFile() throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("PrivatePreview.swift")
        try """
        import SwiftUI

        private struct PrivateHelperView: View {
            var body: some View { Text("Hidden") }
        }

        #Preview {
            PrivateHelperView()
        }
        """.write(to: fileURL, atomically: true, encoding: .utf16)

        let checker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.private.utf16",
            title: "Private UTF16 Preview",
            sourceFileURL: fileURL,
            lineNumber: 7,
            endLineNumber: 9,
            primaryTypeName: "PrivateHelperView",
            bodySource: "PrivateHelperView()",
            sourceText: nil
        )

        #expect(!checker.shouldUseModuleImport(discovery: discovery))
    }

    @Test("rejects module import when preview body references private symbols")
    func rejectsModuleImportForPrivateSymbols() {
        let checker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.private",
            title: "Private Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            primaryTypeName: "PreviewView",
            bodySource: "PrivateHelperView()",
            sourceText: """
            private struct PrivateHelperView: View {
                var body: some View { Text("Hidden") }
            }

            #Preview {
                PrivateHelperView()
            }
            """
        )

        #expect(!checker.shouldUseModuleImport(discovery: discovery))
    }

    @Test("allows module import when preview body references non-private symbols")
    func allowsModuleImportForNonPrivateSymbols() {
        let checker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.internal",
            title: "Internal Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            primaryTypeName: "PreviewView",
            bodySource: "SharedPreviewView()",
            sourceText: """
            struct SharedPreviewView: View {
                var body: some View { Text("Visible") }
            }

            #Preview {
                SharedPreviewView()
            }
            """
        )

        #expect(checker.shouldUseModuleImport(discovery: discovery))
    }

    @Test("rejects construction of types with private initializer only for matching type")
    func rejectsConstructionOfTypesWithPrivateInitializerOnlyForMatchingType() {
        let checker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        let sourceText = """
        struct PublicPreviewView: View {
            var body: some View { Text("Visible") }
        }

        struct PrivateInitPreviewView: View {
            private init() {}
            var body: some View { Text("Hidden") }
        }
        """

        let allowedDiscovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.public-init",
            title: "Public Init Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            primaryTypeName: "PreviewView",
            bodySource: "PublicPreviewView()",
            sourceText: sourceText
        )
        let rejectedDiscovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.private-init",
            title: "Private Init Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 16,
            endLineNumber: 20,
            primaryTypeName: "PreviewView",
            bodySource: "PrivateInitPreviewView()",
            sourceText: sourceText
        )

        #expect(checker.shouldUseModuleImport(discovery: allowedDiscovery))
        #expect(!checker.shouldUseModuleImport(discovery: rejectedDiscovery))
    }

    @Test("allows module import when referenced type has public and private initializers")
    func allowsModuleImportForTypeWithPublicAndPrivateInitializers() {
        let checker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.mixed-init",
            title: "Mixed Init Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 18,
            endLineNumber: 22,
            primaryTypeName: "MixedInitView",
            bodySource: #"MixedInitView("Visible")"#,
            sourceText: #"""
            public struct MixedInitView: View {
                public init(_ title: String) {}

                private init(title: Text) {}

                public var body: some View { Text("Visible") }
            }

            #Preview {
                MixedInitView("Visible")
            }
            """#
        )

        #expect(checker.shouldUseModuleImport(discovery: discovery))
    }

    @Test("does not treat SwiftUI modifier names as private symbol references")
    func ignoresModifierNamesThatMatchPrivateComputedProperties() {
        let checker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.modifier-name",
            title: "Modifier Name Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 14,
            endLineNumber: 18,
            primaryTypeName: "Button",
            bodySource: #"Text("Visible").background(Color.gray)"#,
            sourceText: #"""
            public struct ModifierNameView: View {
                private var background: some View {
                    Color.blue
                }

                public var body: some View { background }
            }

            #Preview {
                Text("Visible").background(Color.gray)
            }
            """#
        )

        #expect(checker.shouldUseModuleImport(discovery: discovery))
    }

    @Test("rejects module import when preview body references private extension members")
    func rejectsModuleImportForPrivateExtensionMembers() {
        let checker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.private-extension",
            title: "Private Extension Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            primaryTypeName: "PreviewView",
            bodySource: "DemoView.makePrivatePreview()",
            sourceText: """
            struct DemoView: View {
                var body: some View { Text("Visible") }
            }

            private extension DemoView {
                static func makePrivatePreview() -> some View {
                    DemoView()
                }
            }
            """
        )

        #expect(!checker.shouldUseModuleImport(discovery: discovery))
    }

    @Test("allows module import for non-private extension members")
    func allowsModuleImportForNonPrivateExtensionMembers() {
        let checker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.public-extension",
            title: "Public Extension Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            primaryTypeName: "PreviewView",
            bodySource: "DemoView.makePreview()",
            sourceText: """
            struct DemoView: View {
                var body: some View { Text("Visible") }
            }

            extension DemoView {
                static func makePreview() -> some View {
                    DemoView()
                }
            }
            """
        )

        #expect(checker.shouldUseModuleImport(discovery: discovery))
    }
}
