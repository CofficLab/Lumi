import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("ModuleImportEligibilityChecker")
struct ModuleImportEligibilityCheckerTests {
    @Test("rejects module import when preview body references private symbols")
    func rejectsModuleImportForPrivateSymbols() {
        let checker = LumiPreviewPackage.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewPackage.PreviewDiscovery(
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
        let checker = LumiPreviewPackage.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewPackage.PreviewDiscovery(
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
        let checker = LumiPreviewPackage.ModuleImportEligibilityChecker()
        let sourceText = """
        struct PublicPreviewView: View {
            var body: some View { Text("Visible") }
        }

        struct PrivateInitPreviewView: View {
            private init() {}
            var body: some View { Text("Hidden") }
        }
        """

        let allowedDiscovery = LumiPreviewPackage.PreviewDiscovery(
            id: "preview.public-init",
            title: "Public Init Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            primaryTypeName: "PreviewView",
            bodySource: "PublicPreviewView()",
            sourceText: sourceText
        )
        let rejectedDiscovery = LumiPreviewPackage.PreviewDiscovery(
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

    @Test("rejects module import when preview body references private extension members")
    func rejectsModuleImportForPrivateExtensionMembers() {
        let checker = LumiPreviewPackage.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewPackage.PreviewDiscovery(
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
        let checker = LumiPreviewPackage.ModuleImportEligibilityChecker()
        let discovery = LumiPreviewPackage.PreviewDiscovery(
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
